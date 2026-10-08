package fraud

import (
	"testing"

	"github.com/ledgerflow/ledgerflow/internal/events"
)

func TestEvaluateApproved(t *testing.T) {
	transaction := events.TransactionEvent{
		EventID:       "evt-001",
		TransactionID: "txn-001",
		AccountID:     "ACC-1001",
		Amount:        1250,
		Currency:      "USD",
	}

	result := Evaluate(transaction)

	if result.Decision != events.FraudDecisionApproved {
		t.Fatalf(
			"expected APPROVED, got %s",
			result.Decision,
		)
	}
}

func TestEvaluateReview(t *testing.T) {
	transaction := events.TransactionEvent{
		EventID:       "evt-002",
		TransactionID: "txn-002",
		AccountID:     "ACC-1001",
		Amount:        7500,
		Currency:      "USD",
	}

	result := Evaluate(transaction)

	if result.Decision != events.FraudDecisionReview {
		t.Fatalf(
			"expected REVIEW, got %s",
			result.Decision,
		)
	}
}

func TestEvaluateBlocked(t *testing.T) {
	transaction := events.TransactionEvent{
		EventID:       "evt-003",
		TransactionID: "txn-003",
		AccountID:     "ACC-1001",
		Amount:        15000,
		Currency:      "USD",
	}

	result := Evaluate(transaction)

	if result.Decision != events.FraudDecisionBlocked {
		t.Fatalf(
			"expected BLOCKED, got %s",
			result.Decision,
		)
	}
}
