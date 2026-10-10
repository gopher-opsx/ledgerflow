// Consumes transaction events, evaluates the lab fraud rules, and publishes fraud outcomes.
// Output publication and input-offset commits are separate operations, so replay can duplicate outputs.

package kafka

import (
	"context"
	"encoding/json"
	"fmt"
	"log"

	"github.com/ledgerflow/ledgerflow/internal/events"
	"github.com/ledgerflow/ledgerflow/internal/fraud"
	"github.com/twmb/franz-go/pkg/kgo"
)

type FraudService struct {
	consumer    *kgo.Client
	producer    *kgo.Client
	outputTopic string
}

func NewFraudService(
	brokers []string,
	inputTopic string,
	outputTopic string,
	groupID string,
) (*FraudService, error) {
	consumer, err := kgo.NewClient(
		kgo.SeedBrokers(brokers...),
		kgo.ConsumerGroup(groupID),
		kgo.ConsumeTopics(inputTopic),
		kgo.DisableAutoCommit(),
	)
	if err != nil {
		return nil, fmt.Errorf(
			"create fraud consumer: %w",
			err,
		)
	}

	producer, err := kgo.NewClient(
		kgo.SeedBrokers(brokers...),
		kgo.RequiredAcks(kgo.AllISRAcks()),
	)
	if err != nil {
		consumer.Close()

		return nil, fmt.Errorf(
			"create fraud producer: %w",
			err,
		)
	}

	return &FraudService{
		consumer:    consumer,
		producer:    producer,
		outputTopic: outputTopic,
	}, nil
}

func (s *FraudService) Run(
	ctx context.Context,
) error {
	for {
		if ctx.Err() != nil {
			return nil
		}

		fetches := s.consumer.PollFetches(ctx)

		if ctx.Err() != nil {
			return nil
		}

		for _, fetchErr := range fetches.Errors() {
			log.Printf(
				"kafka fetch error: %v",
				fetchErr,
			)
		}

		iter := fetches.RecordIter()

		for !iter.Done() {
			record := iter.Next()

			var transaction events.TransactionEvent

			if err := json.Unmarshal(
				record.Value,
				&transaction,
			); err != nil {
				log.Printf(
					"invalid transaction event: %v",
					err,
				)

				continue
			}

			result := fraud.Evaluate(transaction)

			value, err := json.Marshal(result)
			if err != nil {
				log.Printf(
					"marshal fraud result failed: %v",
					err,
				)

				continue
			}

			output := &kgo.Record{
				Topic: s.outputTopic,
				Key: []byte(
					transaction.TransactionID,
				),
				Value: value,
			}

			if err := s.producer.
				ProduceSync(ctx, output).
				FirstErr(); err != nil {

				log.Printf(
					"publish fraud result failed: %v",
					err,
				)

				continue
			}

			if err := s.consumer.CommitRecords(
				ctx,
				record,
			); err != nil {
				log.Printf(
					"commit fraud-service offset failed: %v",
					err,
				)

				continue
			}

			log.Printf(
				"fraud result: transaction=%s decision=%s",
				transaction.TransactionID,
				result.Decision,
			)
		}
	}
}

func (s *FraudService) Close() {
	s.consumer.Close()
	s.producer.Close()
}
