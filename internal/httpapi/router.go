package httpapi

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sync/atomic"
	"time"

	"github.com/ledgerflow/ledgerflow/internal/events"
	"github.com/ledgerflow/ledgerflow/internal/kafka"
)

var ready atomic.Bool

var acceptedRequests atomic.Uint64
var invalidJSONRequests atomic.Uint64
var validationErrorRequests atomic.Uint64
var kafkaPublishErrors atomic.Uint64

func init() {
	ready.Store(true)
}

func NewRouter(producer kafka.Producer) http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc(
		"GET /health/live",
		liveHandler,
	)

	mux.HandleFunc(
		"GET /health/ready",
		readyHandler,
	)

	mux.HandleFunc(
		"GET /metrics",
		metricsHandler,
	)

	mux.HandleFunc(
		"POST /api/v1/transactions",
		createTransactionHandler(producer),
	)

	return mux
}

func liveHandler(
	w http.ResponseWriter,
	_ *http.Request,
) {
	writeJSON(
		w,
		http.StatusOK,
		map[string]string{
			"status":  "ok",
			"service": "transaction-api",
		},
	)
}

func readyHandler(
	w http.ResponseWriter,
	_ *http.Request,
) {
	if !ready.Load() {
		writeJSON(
			w,
			http.StatusServiceUnavailable,
			map[string]string{
				"status":  "not-ready",
				"service": "transaction-api",
			},
		)

		return
	}

	writeJSON(
		w,
		http.StatusOK,
		map[string]string{
			"status":  "ready",
			"service": "transaction-api",
		},
	)
}

func metricsHandler(
	w http.ResponseWriter,
	_ *http.Request,
) {
	w.Header().Set(
		"Content-Type",
		"text/plain; version=0.0.4",
	)

	_, _ = fmt.Fprintf(
		w,
		"# HELP ledgerflow_transaction_api_requests_total Total transaction API requests by result.\n"+
			"# TYPE ledgerflow_transaction_api_requests_total counter\n"+
			"ledgerflow_transaction_api_requests_total{result=\"accepted\"} %d\n"+
			"ledgerflow_transaction_api_requests_total{result=\"invalid_json\"} %d\n"+
			"ledgerflow_transaction_api_requests_total{result=\"validation_error\"} %d\n"+
			"ledgerflow_transaction_api_requests_total{result=\"kafka_publish_error\"} %d\n",
		acceptedRequests.Load(),
		invalidJSONRequests.Load(),
		validationErrorRequests.Load(),
		kafkaPublishErrors.Load(),
	)
}

func createTransactionHandler(
	producer kafka.Producer,
) http.HandlerFunc {
	return func(
		w http.ResponseWriter,
		r *http.Request,
	) {
		defer r.Body.Close()

		var event events.TransactionEvent

		decoder := json.NewDecoder(
			http.MaxBytesReader(
				w,
				r.Body,
				1<<20,
			),
		)

		decoder.DisallowUnknownFields()

		if err := decoder.Decode(&event); err != nil {
			invalidJSONRequests.Add(1)

			writeJSON(
				w,
				http.StatusBadRequest,
				map[string]string{
					"error": "invalid request body",
				},
			)

			return
		}

		if event.Timestamp.IsZero() {
			event.Timestamp = time.Now().UTC()
		}

		if err := event.Validate(); err != nil {
			validationErrorRequests.Add(1)

			writeJSON(
				w,
				http.StatusBadRequest,
				map[string]string{
					"error": err.Error(),
				},
			)

			return
		}

		if err := producer.PublishTransaction(
			r.Context(),
			event,
		); err != nil {
			kafkaPublishErrors.Add(1)

			writeJSON(
				w,
				http.StatusServiceUnavailable,
				map[string]string{
					"error": "failed to publish transaction",
				},
			)

			return
		}

		acceptedRequests.Add(1)

		writeJSON(
			w,
			http.StatusAccepted,
			map[string]string{
				"status":         "accepted",
				"event_id":       event.EventID,
				"transaction_id": event.TransactionID,
			},
		)
	}
}

func writeJSON(
	w http.ResponseWriter,
	status int,
	body any,
) {
	w.Header().Set(
		"Content-Type",
		"application/json",
	)

	w.WriteHeader(status)

	_ = json.NewEncoder(w).Encode(body)
}
