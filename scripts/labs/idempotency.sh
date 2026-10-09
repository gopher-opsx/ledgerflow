#!/usr/bin/env bash
set -euo pipefail

API_URL="${API_URL:-http://localhost:8080}"
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-ledgerflow-postgres}"
STAMP="$(date +%s)"
EVENT_ID="evt-idempotency-${STAMP}"
TRANSACTION_ID="txn-idempotency-${STAMP}"

PAYLOAD="{\"event_id\":\"${EVENT_ID}\",\"transaction_id\":\"${TRANSACTION_ID}\",\"account_id\":\"ACC-IDEMPOTENCY\",\"type\":\"TRANSFER\",\"amount\":125,\"currency\":\"USD\",\"destination_account\":\"ACC-IDEMPOTENCY-DEST\"}"

for attempt in 1 2; do
    curl --fail --silent \
        -H 'Content-Type: application/json' \
        --data "${PAYLOAD}" \
        "${API_URL}/api/v1/transactions" >/dev/null
    echo "✓ Published duplicate attempt ${attempt}"
done

sleep 3

TX_COUNT="$(docker exec "${POSTGRES_CONTAINER}" psql -U ledgerflow -d ledgerflow -tAc "SELECT COUNT(*) FROM transactions WHERE event_id='${EVENT_ID}';")"
ENTRY_COUNT="$(docker exec "${POSTGRES_CONTAINER}" psql -U ledgerflow -d ledgerflow -tAc "SELECT COUNT(*) FROM ledger_entries WHERE transaction_id='${TRANSACTION_ID}';")"
PROCESSED_COUNT="$(docker exec "${POSTGRES_CONTAINER}" psql -U ledgerflow -d ledgerflow -tAc "SELECT COUNT(*) FROM processed_events WHERE event_id='${EVENT_ID}';")"

printf 'transactions=%s ledger_entries=%s processed_events=%s\n' "${TX_COUNT}" "${ENTRY_COUNT}" "${PROCESSED_COUNT}"

if [ "${TX_COUNT}" != "1" ] || [ "${ENTRY_COUNT}" != "2" ] || [ "${PROCESSED_COUNT}" != "1" ]; then
    echo "✗ Idempotent ledger verification failed"
    exit 1
fi

echo "✓ Duplicate event produced only one durable ledger transaction"
