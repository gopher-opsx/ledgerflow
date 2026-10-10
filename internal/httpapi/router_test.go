// Tests the httpapi package with controlled inputs and expected outcomes.
// These checks cover local behavior; they do not validate a deployed Kafka or PostgreSQL system.

package httpapi

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestHealthLive(t *testing.T) {
	producer := &testProducer{}

	req := httptest.NewRequest(
		http.MethodGet,
		"/health/live",
		nil,
	)

	rec := httptest.NewRecorder()

	NewRouter(
		producer,
	).ServeHTTP(
		rec,
		req,
	)

	if rec.Code != http.StatusOK {
		t.Fatalf(
			"expected 200, got %d",
			rec.Code,
		)
	}
}

func TestCreateTransactionAccepted(t *testing.T) {
	producer := &testProducer{}

	body := `{
		"event_id":"evt-100001",
		"transaction_id":"txn-100001",
		"account_id":"ACC-1001",
		"type":"TRANSFER",
		"amount":1250,
		"currency":"USD",
		"destination_account":"ACC-2001",
		"timestamp":"2026-10-08T12:00:00Z"
	}`

	req := httptest.NewRequest(
		http.MethodPost,
		"/api/v1/transactions",
		strings.NewReader(body),
	)

	rec := httptest.NewRecorder()

	NewRouter(
		producer,
	).ServeHTTP(
		rec,
		req,
	)

	if rec.Code != http.StatusAccepted {
		t.Fatalf(
			"expected 202, got %d: %s",
			rec.Code,
			rec.Body.String(),
		)
	}

	if producer.event.EventID != "evt-100001" {
		t.Fatalf(
			"expected event evt-100001, got %s",
			producer.event.EventID,
		)
	}

	if producer.event.TransactionID != "txn-100001" {
		t.Fatalf(
			"expected transaction txn-100001, got %s",
			producer.event.TransactionID,
		)
	}
}

func TestCreateTransactionRejectsInvalidAmount(
	t *testing.T,
) {
	producer := &testProducer{}

	body := `{
		"event_id":"evt-100001",
		"transaction_id":"txn-100001",
		"account_id":"ACC-1001",
		"type":"TRANSFER",
		"amount":0,
		"currency":"USD",
		"destination_account":"ACC-2001",
		"timestamp":"2026-10-08T12:00:00Z"
	}`

	req := httptest.NewRequest(
		http.MethodPost,
		"/api/v1/transactions",
		strings.NewReader(body),
	)

	rec := httptest.NewRecorder()

	NewRouter(
		producer,
	).ServeHTTP(
		rec,
		req,
	)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf(
			"expected 400, got %d",
			rec.Code,
		)
	}
}

func TestCreateTransactionReturns503WhenKafkaFails(
	t *testing.T,
) {
	producer := &testProducer{
		err: errors.New("kafka unavailable"),
	}

	body := `{
		"event_id":"evt-100002",
		"transaction_id":"txn-100002",
		"account_id":"ACC-1001",
		"type":"TRANSFER",
		"amount":1250,
		"currency":"USD",
		"destination_account":"ACC-2001",
		"timestamp":"2026-10-08T12:00:00Z"
	}`

	req := httptest.NewRequest(
		http.MethodPost,
		"/api/v1/transactions",
		strings.NewReader(body),
	)

	rec := httptest.NewRecorder()

	NewRouter(
		producer,
	).ServeHTTP(
		rec,
		req,
	)

	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf(
			"expected 503, got %d: %s",
			rec.Code,
			rec.Body.String(),
		)
	}
}
