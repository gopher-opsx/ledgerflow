package kafka

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/ledgerflow/ledgerflow/internal/events"
	"github.com/twmb/franz-go/pkg/kgo"
)

type Producer interface {
	PublishTransaction(context.Context, events.TransactionEvent) error
	Close()
}

type KafkaProducer struct {
	client *kgo.Client
	topic  string
}

func NewProducer(brokers []string, topic string) (*KafkaProducer, error) {
	client, err := kgo.NewClient(
		kgo.SeedBrokers(brokers...),
		kgo.RequiredAcks(kgo.AllISRAcks()),
	)

	if err != nil {
		return nil, fmt.Errorf("create kafka client: %w", err)
	}

	return &KafkaProducer{
		client: client,
		topic:  topic,
	}, nil
}

func (p *KafkaProducer) PublishTransaction(
	ctx context.Context,
	event events.TransactionEvent,
) error {
	value, err := json.Marshal(event)
	if err != nil {
		return fmt.Errorf("marshal transaction event: %w", err)
	}

	record := &kgo.Record{
		Topic: p.topic,

		// Transactions for the same account use the same Kafka key.
		// This provides deterministic partitioning and per-account ordering.
		Key: []byte(event.AccountID),

		Value: value,
	}

	result := p.client.ProduceSync(ctx, record)

	if err := result.FirstErr(); err != nil {
		return fmt.Errorf("produce transaction event: %w", err)
	}

	return nil
}

func (p *KafkaProducer) Close() {
	p.client.Close()
}
