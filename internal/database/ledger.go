// Persists a transaction, its debit and credit entries, and its processed-event marker together.
// The database transaction prevents partial ledger writes; an existing event ID is ignored.

package database

import (
	"context"
	"fmt"

	"github.com/ledgerflow/ledgerflow/internal/events"
)

func (db *DB) ProcessTransaction(
	ctx context.Context,
	event events.TransactionEvent,
) (bool, error) {
	tx, err := db.Pool.Begin(ctx)
	if err != nil {
		return false, fmt.Errorf("begin transaction: %w", err)
	}

	defer func() {
		_ = tx.Rollback(ctx)
	}()

	var alreadyProcessed bool

	err = tx.QueryRow(
		ctx,
		`
		SELECT EXISTS (
			SELECT 1
			FROM processed_events
			WHERE event_id = $1
		)
		`,
		event.EventID,
	).Scan(&alreadyProcessed)

	if err != nil {
		return false, fmt.Errorf(
			"check processed event: %w",
			err,
		)
	}

	if alreadyProcessed {
		return false, nil
	}

	_, err = tx.Exec(
		ctx,
		`
		INSERT INTO transactions (
			transaction_id,
			event_id,
			account_id,
			destination_account,
			transaction_type,
			amount,
			currency,
			event_timestamp
		)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
		`,
		event.TransactionID,
		event.EventID,
		event.AccountID,
		event.DestinationAccount,
		event.Type,
		event.Amount,
		event.Currency,
		event.Timestamp,
	)

	if err != nil {
		return false, fmt.Errorf(
			"insert transaction: %w",
			err,
		)
	}

	_, err = tx.Exec(
		ctx,
		`
		INSERT INTO ledger_entries (
			transaction_id,
			account_id,
			direction,
			amount,
			currency
		)
		VALUES ($1,$2,'DEBIT',$3,$4)
		`,
		event.TransactionID,
		event.AccountID,
		event.Amount,
		event.Currency,
	)

	if err != nil {
		return false, fmt.Errorf(
			"insert debit ledger entry: %w",
			err,
		)
	}

	_, err = tx.Exec(
		ctx,
		`
		INSERT INTO ledger_entries (
			transaction_id,
			account_id,
			direction,
			amount,
			currency
		)
		VALUES ($1,$2,'CREDIT',$3,$4)
		`,
		event.TransactionID,
		event.DestinationAccount,
		event.Amount,
		event.Currency,
	)

	if err != nil {
		return false, fmt.Errorf(
			"insert credit ledger entry: %w",
			err,
		)
	}

	_, err = tx.Exec(
		ctx,
		`
		INSERT INTO processed_events (
			event_id,
			consumer_name
		)
		VALUES ($1,'ledger-service')
		`,
		event.EventID,
	)

	if err != nil {
		return false, fmt.Errorf(
			"insert processed event: %w",
			err,
		)
	}

	if err := tx.Commit(ctx); err != nil {
		return false, fmt.Errorf(
			"commit transaction: %w",
			err,
		)
	}

	return true, nil
}
