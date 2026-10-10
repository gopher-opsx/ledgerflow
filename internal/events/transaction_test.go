// Tests the events package with controlled inputs and expected outcomes.
// These checks cover local behavior; they do not validate a deployed Kafka or PostgreSQL system.

package events

import (
	"testing"
	"time"
)

func TestTransactionEventValidate(t *testing.T) {
	valid := TransactionEvent{
		EventID:            "evt-100001",
		TransactionID:      "txn-100001",
		AccountID:          "ACC-1001",
		Type:               TransactionTypeTransfer,
		Amount:             1250,
		Currency:           "USD",
		DestinationAccount: "ACC-2001",
		Timestamp:          time.Date(2026, 10, 8, 12, 0, 0, 0, time.UTC),
	}

	if err := valid.Validate(); err != nil {
		t.Fatalf("expected valid event, got %v", err)
	}

	invalid := valid
	invalid.Amount = 0

	if err := invalid.Validate(); err == nil {
		t.Fatal("expected validation error for zero amount")
	}
}
