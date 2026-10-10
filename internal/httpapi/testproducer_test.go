// Provides an in-memory producer double for HTTP endpoint tests.
// Capturing the event and injecting errors tests API behavior without a running Kafka cluster.

package httpapi

import (
	"context"

	"github.com/ledgerflow/ledgerflow/internal/events"
)

type testProducer struct {
	event events.TransactionEvent
	err   error
}

func (p *testProducer) PublishTransaction(
	_ context.Context,
	event events.TransactionEvent,
) error {
	p.event = event

	return p.err
}

func (p *testProducer) Close() {}
