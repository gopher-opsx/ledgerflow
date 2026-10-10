// Defines the fraud-result event contract produced by the fraud consumer.
// Keep these fields aligned with topic readers and fixture expectations.

package events

import "time"

type FraudDecision string

const (
	FraudDecisionApproved FraudDecision = "APPROVED"
	FraudDecisionReview   FraudDecision = "REVIEW"
	FraudDecisionBlocked  FraudDecision = "BLOCKED"
)

type FraudResultEvent struct {
	EventID       string        `json:"event_id"`
	TransactionID string        `json:"transaction_id"`
	AccountID     string        `json:"account_id"`
	Amount        float64       `json:"amount"`
	Currency      string        `json:"currency"`
	Decision      FraudDecision `json:"decision"`
	Reason        string        `json:"reason"`
	Timestamp     time.Time     `json:"timestamp"`
}
