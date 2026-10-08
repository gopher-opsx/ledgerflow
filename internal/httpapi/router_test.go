package httpapi

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestHealthLive(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/health/live", nil)
	rec := httptest.NewRecorder()

	NewRouter().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
}

func TestCreateTransactionAccepted(t *testing.T) {
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

	req := httptest.NewRequest(http.MethodPost, "/api/v1/transactions", strings.NewReader(body))
	rec := httptest.NewRecorder()

	NewRouter().ServeHTTP(rec, req)

	if rec.Code != http.StatusAccepted {
		t.Fatalf("expected 202, got %d: %s", rec.Code, rec.Body.String())
	}
}

func TestCreateTransactionRejectsInvalidAmount(t *testing.T) {
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

	req := httptest.NewRequest(http.MethodPost, "/api/v1/transactions", strings.NewReader(body))
	rec := httptest.NewRecorder()

	NewRouter().ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}
