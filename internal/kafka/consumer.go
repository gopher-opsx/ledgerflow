// Runs the ledger consumer with explicit commits, database retries, and dead-letter publication.
// The normal path commits after persistence or successful DLT publication; see the review for failure-path limitations.

package kafka

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"strconv"
	"time"

	"github.com/ledgerflow/ledgerflow/internal/database"
	"github.com/ledgerflow/ledgerflow/internal/events"
	"github.com/twmb/franz-go/pkg/kgo"
)

type TransactionConsumer struct {
	client       *kgo.Client
	dltProducer  *kgo.Client
	db           *database.DB
	dltTopic     string
	maxRetries   int
	retryBackoff time.Duration
}

func NewTransactionConsumer(
	brokers []string,
	topic string,
	groupID string,
	dltTopic string,
	maxRetries int,
	db *database.DB,
) (*TransactionConsumer, error) {
	client, err := kgo.NewClient(
		kgo.SeedBrokers(brokers...),
		kgo.ConsumerGroup(groupID),
		kgo.ConsumeTopics(topic),
		kgo.DisableAutoCommit(),
	)
	if err != nil {
		return nil, fmt.Errorf("create kafka consumer: %w", err)
	}

	dltProducer, err := kgo.NewClient(
		kgo.SeedBrokers(brokers...),
		kgo.RequiredAcks(kgo.AllISRAcks()),
	)
	if err != nil {
		client.Close()
		return nil, fmt.Errorf("create dlt producer: %w", err)
	}

	if maxRetries < 0 {
		maxRetries = 0
	}

	return &TransactionConsumer{
		client:       client,
		dltProducer:  dltProducer,
		db:           db,
		dltTopic:     dltTopic,
		maxRetries:   maxRetries,
		retryBackoff: time.Second,
	}, nil
}

func (c *TransactionConsumer) Run(ctx context.Context) error {
	for {
		if ctx.Err() != nil {
			return nil
		}

		fetches := c.client.PollFetches(ctx)
		for _, fetchErr := range fetches.Errors() {
			log.Printf("kafka fetch error: %v", fetchErr)
		}

		iter := fetches.RecordIter()
		for !iter.Done() {
			record := iter.Next()

			var event events.TransactionEvent
			if err := json.Unmarshal(record.Value, &event); err != nil {
				log.Printf("invalid transaction event: %v", err)
				if err := c.publishDLT(ctx, record, "invalid_json", err); err != nil {
					log.Printf("publish invalid event to DLT failed: %v", err)
					continue
				}
				c.commit(ctx, record)
				continue
			}

			processed, err := c.processWithRetry(ctx, event)
			if err != nil {
				log.Printf("process transaction %s failed after retries: %v", event.TransactionID, err)
				if dltErr := c.publishDLT(ctx, record, "processing_failed", err); dltErr != nil {
					log.Printf("publish failed event to DLT failed: %v", dltErr)
					continue
				}
				c.commit(ctx, record)
				continue
			}

			if processed {
				log.Printf("transaction persisted: %s", event.TransactionID)
			} else {
				log.Printf("duplicate event ignored: %s", event.EventID)
			}

			c.commit(ctx, record)
		}
	}
}

func (c *TransactionConsumer) processWithRetry(ctx context.Context, event events.TransactionEvent) (bool, error) {
	var lastErr error
	for attempt := 0; attempt <= c.maxRetries; attempt++ {
		processed, err := c.db.ProcessTransaction(ctx, event)
		if err == nil {
			return processed, nil
		}
		lastErr = err
		if attempt == c.maxRetries {
			break
		}
		log.Printf("retry transaction=%s attempt=%d/%d error=%v", event.TransactionID, attempt+1, c.maxRetries, err)
		select {
		case <-ctx.Done():
			return false, ctx.Err()
		case <-time.After(c.retryBackoff):
		}
	}
	return false, lastErr
}

func (c *TransactionConsumer) publishDLT(ctx context.Context, source *kgo.Record, reason string, cause error) error {
	if c.dltTopic == "" {
		return fmt.Errorf("DLT topic is not configured")
	}

	record := &kgo.Record{
		Topic: c.dltTopic,
		Key:   source.Key,
		Value: source.Value,
		Headers: []kgo.RecordHeader{
			{Key: "ledgerflow-source-topic", Value: []byte(source.Topic)},
			{Key: "ledgerflow-source-partition", Value: []byte(strconv.Itoa(int(source.Partition)))},
			{Key: "ledgerflow-source-offset", Value: []byte(strconv.FormatInt(source.Offset, 10))},
			{Key: "ledgerflow-dlt-reason", Value: []byte(reason)},
			{Key: "ledgerflow-dlt-error", Value: []byte(cause.Error())},
		},
	}

	if err := c.dltProducer.ProduceSync(ctx, record).FirstErr(); err != nil {
		return fmt.Errorf("produce DLT record: %w", err)
	}
	return nil
}

func (c *TransactionConsumer) commit(ctx context.Context, record *kgo.Record) {
	if err := c.client.CommitRecords(ctx, record); err != nil {
		log.Printf("commit kafka offset failed: %v", err)
	}
}

func (c *TransactionConsumer) Close() {
	c.client.Close()
	c.dltProducer.Close()
}
