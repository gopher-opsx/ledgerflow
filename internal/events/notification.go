// Defines the simulated notification event contract.
// A notification record represents a lab outcome; it is not proof of an email delivery.

package events

import "time"

type NotificationStatus string

const (
	NotificationStatusSent NotificationStatus = "SENT"
)

type NotificationEvent struct {
	EventID       string             `json:"event_id"`
	TransactionID string             `json:"transaction_id"`
	AccountID     string             `json:"account_id"`
	Channel       string             `json:"channel"`
	Status        NotificationStatus `json:"status"`
	Message       string             `json:"message"`
	Timestamp     time.Time          `json:"timestamp"`
}
