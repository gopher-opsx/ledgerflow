package fraud

import (
	"fmt"
	"time"

	"github.com/ledgerflow/ledgerflow/internal/events"
)

func Evaluate(
	transaction events.TransactionEvent,
) events.FraudResultEvent {
	result := events.FraudResultEvent{
		EventID:       fmt.Sprintf("fraud-%s", transaction.EventID),
		TransactionID: transaction.TransactionID,
		AccountID:     transaction.AccountID,
		Amount:        transaction.Amount,
		Currency:      transaction.Currency,
		Timestamp:     time.Now().UTC(),
	}

	switch {
	case transaction.Amount >= 10000:
		result.Decision = events.FraudDecisionBlocked
		result.Reason = "transaction amount exceeds blocking threshold"

	case transaction.Amount >= 5000:
		result.Decision = events.FraudDecisionReview
		result.Reason = "transaction amount requires manual review"

	default:
		result.Decision = events.FraudDecisionApproved
		result.Reason = "transaction passed deterministic fraud checks"
	}

	return result
}
