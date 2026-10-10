// Builds a simulated notification from a transaction with a derived event ID and current timestamp.
// The SENT status is a teaching fixture, not confirmation from an external messaging provider.

package notification

import (
	"fmt"
	"time"

	"github.com/ledgerflow/ledgerflow/internal/events"
)

func Build(
	transaction events.TransactionEvent,
) events.NotificationEvent {
	return events.NotificationEvent{
		EventID:       fmt.Sprintf("notification-%s", transaction.EventID),
		TransactionID: transaction.TransactionID,
		AccountID:     transaction.AccountID,
		Channel:       "EMAIL",
		Status:        events.NotificationStatusSent,
		Message: fmt.Sprintf(
			"Transaction %s processed",
			transaction.TransactionID,
		),
		Timestamp: time.Now().UTC(),
	}
}
