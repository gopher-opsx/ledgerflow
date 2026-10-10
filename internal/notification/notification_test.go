// Tests the notification package with controlled inputs and expected outcomes.
// These checks cover local behavior; they do not validate a deployed Kafka or PostgreSQL system.

package notification

import (
	"testing"

	"github.com/ledgerflow/ledgerflow/internal/events"
)

func TestBuild(t *testing.T) {
	transaction := events.TransactionEvent{
		EventID:       "evt-001",
		TransactionID: "txn-001",
		AccountID:     "ACC-1001",
	}

	result := Build(transaction)

	if result.EventID != "notification-evt-001" {
		t.Fatalf(
			"unexpected event id: %s",
			result.EventID,
		)
	}

	if result.Status != events.NotificationStatusSent {
		t.Fatalf(
			"expected SENT, got %s",
			result.Status,
		)
	}

	if result.Channel != "EMAIL" {
		t.Fatalf(
			"expected EMAIL, got %s",
			result.Channel,
		)
	}
}
