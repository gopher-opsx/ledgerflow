# LedgerFlow

LedgerFlow is the banking transaction platform used by the course
**Apache Kafka & Kubernetes: Production Operations**.

This repository is intentionally focused on production engineering exercises:
Kafka, KRaft, observability, troubleshooting, integrations, security and Kubernetes.

## Current implementation milestone

Implemented:

- Go module
- Transaction API
- Transaction event contract
- Request validation
- Liveness and readiness endpoints
- Prometheus metrics endpoint
- PostgreSQL base schema
- Deterministic synthetic transaction fixtures
- Unit tests
- VS Code launch configuration

Kafka publishing and the three consumer services are the next milestone.

## Run locally

```bash
go mod tidy
make test
make vet
make build
make run-api
```

Then:

```bash
curl http://localhost:8080/health/live
curl http://localhost:8080/health/ready
curl http://localhost:8080/metrics
curl -i \
  -H 'Content-Type: application/json' \
  --data @fixtures/transaction-approved.json \
  http://localhost:8080/api/v1/transactions
```

Expected transaction response:

```json
{
  "status": "accepted",
  "event_id": "evt-100001",
  "transaction_id": "txn-100001"
}
```
