package kafka

import (
	"context"
	"encoding/json"
	"fmt"
	"log"

	"github.com/ledgerflow/ledgerflow/internal/database"
	"github.com/ledgerflow/ledgerflow/internal/events"
	"github.com/twmb/franz-go/pkg/kgo"
)

type TransactionConsumer struct {
	client *kgo.Client
	db     *database.DB
}

func NewTransactionConsumer(
	brokers []string,
	topic string,
	groupID string,
	db *database.DB,
) (*TransactionConsumer, error) {
	client, err := kgo.NewClient(
		kgo.SeedBrokers(brokers...),
		kgo.ConsumerGroup(groupID),
		kgo.ConsumeTopics(topic),
		kgo.DisableAutoCommit(),
	)

	if err != nil {
		return nil, fmt.Errorf(
			"create kafka consumer: %w",
			err,
		)
	}

	return &TransactionConsumer{
		client: client,
		db:     db,
	}, nil
}

func (c *TransactionConsumer) Run(
	ctx context.Context,
) error {
	for {
		if ctx.Err() != nil {
			return nil
		}

		fetches := c.client.PollFetches(ctx)

		if errs := fetches.Errors(); len(errs) > 0 {
			for _, fetchErr := range errs {
				log.Printf(
					"kafka fetch error: %v",
					fetchErr,
				)
			}
		}

		iter := fetches.RecordIter()

		for !iter.Done() {
			record := iter.Next()

			var event events.TransactionEvent

			if err := json.Unmarshal(
				record.Value,
				&event,
			); err != nil {
				log.Printf(
					"invalid transaction event: %v",
					err,
				)

				continue
			}

			processed, err := c.db.ProcessTransaction(
				ctx,
				event,
			)

			if err != nil {
				log.Printf(
					"process transaction %s failed: %v",
					event.TransactionID,
					err,
				)

				continue
			}

			if processed {
				log.Printf(
					"transaction persisted: %s",
					event.TransactionID,
				)
			} else {
				log.Printf(
					"duplicate event ignored: %s",
					event.EventID,
				)
			}

			if err := c.client.CommitRecords(
				ctx,
				record,
			); err != nil {
				log.Printf(
					"commit kafka offset failed: %v",
					err,
				)
			}
		}
	}
}

func (c *TransactionConsumer) Close() {
	c.client.Close()
}
