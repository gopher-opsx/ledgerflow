#!/usr/bin/env bash
# Submits a unique synthetic transaction and checks PostgreSQL, fraud, and notification outputs.
# Run from the repository root in Bash with the required lab services and tools available.

set -euo pipefail

API_URL="${API_URL:-http://localhost:8080}"
POSTGRES_CONTAINER="ledgerflow-postgres"
KAFKA_CONTAINER="ledgerflow-broker-1"
BOOTSTRAP_SERVER="broker-1:19092"

STAMP="$(date +%s)"

EVENT_ID="evt-smoke-${STAMP}"
TRANSACTION_ID="txn-smoke-${STAMP}"

echo
echo "LedgerFlow smoke test"
echo "====================="
echo

echo "1. Checking Transaction API..."

curl --fail --silent \
    "${API_URL}/health/live" \
    >/dev/null

echo "✓ Transaction API healthy"

echo
echo "2. Sending transaction ${TRANSACTION_ID}..."

RESPONSE="$(curl --fail --silent \
    -H "Content-Type: application/json" \
    --data "{
        \"event_id\":\"${EVENT_ID}\",
        \"transaction_id\":\"${TRANSACTION_ID}\",
        \"account_id\":\"ACC-SMOKE-1001\",
        \"type\":\"TRANSFER\",
        \"amount\":3200,
        \"currency\":\"USD\",
        \"destination_account\":\"ACC-SMOKE-2001\"
    }" \
    "${API_URL}/api/v1/transactions")"

echo "${RESPONSE}"

if ! echo "${RESPONSE}" | grep -q "${TRANSACTION_ID}"; then
    echo "✗ Transaction API did not accept expected transaction"
    exit 1
fi

echo "✓ Transaction accepted"

echo
echo "3. Waiting for Ledger Service..."

LEDGER_FOUND="false"

for attempt in {1..20}; do

    RESULT="$(docker exec "${POSTGRES_CONTAINER}" \
        psql \
        -U ledgerflow \
        -d ledgerflow \
        -tAc \
        "SELECT COUNT(*) FROM transactions WHERE transaction_id='${TRANSACTION_ID}';")"

    if [ "${RESULT}" = "1" ]; then
        LEDGER_FOUND="true"
        break
    fi

    sleep 1
done

if [ "${LEDGER_FOUND}" != "true" ]; then
    echo "✗ Ledger transaction was not persisted"
    exit 1
fi

echo "✓ Ledger transaction persisted"

echo
echo "4. Checking ledger entries..."

ENTRY_COUNT="$(docker exec "${POSTGRES_CONTAINER}" \
    psql \
    -U ledgerflow \
    -d ledgerflow \
    -tAc \
    "SELECT COUNT(*) FROM ledger_entries WHERE transaction_id='${TRANSACTION_ID}';")"

if [ "${ENTRY_COUNT}" != "2" ]; then
    echo "✗ Expected 2 ledger entries, found ${ENTRY_COUNT}"
    exit 1
fi

echo "✓ Debit and credit ledger entries persisted"

echo
echo "5. Checking processed-event protection..."

PROCESSED_COUNT="$(docker exec "${POSTGRES_CONTAINER}" \
    psql \
    -U ledgerflow \
    -d ledgerflow \
    -tAc \
    "SELECT COUNT(*) FROM processed_events WHERE event_id='${EVENT_ID}';")"

if [ "${PROCESSED_COUNT}" != "1" ]; then
    echo "✗ Event processing marker missing"
    exit 1
fi

echo "✓ Event marked processed"

echo
echo "6. Checking Fraud Service..."

FRAUD_MESSAGES="$(docker exec "${KAFKA_CONTAINER}" sh -c \
    "/opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server ${BOOTSTRAP_SERVER} \
    --topic ledgerflow.fraud-results \
    --from-beginning \
    --timeout-ms 5000 2>/dev/null || true")"

if ! echo "${FRAUD_MESSAGES}" | grep -q "${TRANSACTION_ID}"; then
    echo "✗ Fraud result not found"
    exit 1
fi

echo "✓ Fraud result published"

echo
echo "7. Checking Notification Service..."

NOTIFICATION_MESSAGES="$(docker exec "${KAFKA_CONTAINER}" sh -c \
    "/opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server ${BOOTSTRAP_SERVER} \
    --topic ledgerflow.notifications \
    --from-beginning \
    --timeout-ms 5000 2>/dev/null || true")"

if ! echo "${NOTIFICATION_MESSAGES}" | grep -q "${TRANSACTION_ID}"; then
    echo "✗ Notification event not found"
    exit 1
fi

echo "✓ Notification published"

echo
echo "=============================="
echo "LedgerFlow smoke test PASSED"
echo "=============================="
echo
echo "Transaction: ${TRANSACTION_ID}"