package events

import (
	"errors"
	"strings"
	"time"
)

type TransactionType string

const (
	TransactionTypeTransfer TransactionType = "TRANSFER"
)

type TransactionEvent struct {
	EventID            string          `json:"event_id"`
	TransactionID      string          `json:"transaction_id"`
	AccountID          string          `json:"account_id"`
	Type               TransactionType `json:"type"`
	Amount             float64         `json:"amount"`
	Currency           string          `json:"currency"`
	DestinationAccount string          `json:"destination_account"`
	Timestamp          time.Time       `json:"timestamp"`
}

func (e TransactionEvent) Validate() error {
	if strings.TrimSpace(e.EventID) == "" {
		return errors.New("event_id is required")
	}
	if strings.TrimSpace(e.TransactionID) == "" {
		return errors.New("transaction_id is required")
	}
	if strings.TrimSpace(e.AccountID) == "" {
		return errors.New("account_id is required")
	}
	if e.Type != TransactionTypeTransfer {
		return errors.New("type must be TRANSFER")
	}
	if e.Amount <= 0 {
		return errors.New("amount must be greater than zero")
	}
	if strings.TrimSpace(e.Currency) == "" {
		return errors.New("currency is required")
	}
	if strings.TrimSpace(e.DestinationAccount) == "" {
		return errors.New("destination_account is required")
	}
	if e.Timestamp.IsZero() {
		return errors.New("timestamp is required")
	}

	return nil
}
