// Consumes transactions and publishes simulated notification records.
// This service does not send email; output publication and offset commits are separate operations.

package kafka

import (
	"context"
	"encoding/json"
	"fmt"
	"log"

	"github.com/ledgerflow/ledgerflow/internal/events"
	"github.com/ledgerflow/ledgerflow/internal/notification"
	"github.com/twmb/franz-go/pkg/kgo"
)

type NotificationService struct {
	consumer    *kgo.Client
	producer    *kgo.Client
	outputTopic string
}

func NewNotificationService(
	brokers []string,
	inputTopic string,
	outputTopic string,
	groupID string,
) (*NotificationService, error) {
	consumer, err := kgo.NewClient(
		kgo.SeedBrokers(brokers...),
		kgo.ConsumerGroup(groupID),
		kgo.ConsumeTopics(inputTopic),
		kgo.DisableAutoCommit(),
	)

	if err != nil {
		return nil, fmt.Errorf(
			"create notification consumer: %w",
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
			"create notification producer: %w",
			err,
		)
	}

	return &NotificationService{
		consumer:    consumer,
		producer:    producer,
		outputTopic: outputTopic,
	}, nil
}

func (s *NotificationService) Run(
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

			result := notification.Build(
				transaction,
			)

			value, err := json.Marshal(result)
			if err != nil {
				log.Printf(
					"marshal notification failed: %v",
					err,
				)

				continue
			}

			output := &kgo.Record{
				Topic: s.outputTopic,
				Key: []byte(
					transaction.AccountID,
				),
				Value: value,
			}

			if err := s.producer.
				ProduceSync(ctx, output).
				FirstErr(); err != nil {

				log.Printf(
					"publish notification failed: %v",
					err,
				)

				continue
			}

			if err := s.consumer.CommitRecords(
				ctx,
				record,
			); err != nil {

				log.Printf(
					"commit notification offset failed: %v",
					err,
				)

				continue
			}

			log.Printf(
				"notification sent: transaction=%s",
				transaction.TransactionID,
			)
		}
	}
}

func (s *NotificationService) Close() {
	s.consumer.Close()
	s.producer.Close()
}
