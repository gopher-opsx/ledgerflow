#!/usr/bin/env bash
# Lesson 30: Demonstrate a first delivery, then a repeated delivery, without duplicate financial effects.
# Preserves all existing transactions, topics and data. Run with the base Kafka application stack.
set -euo pipefail

API_URL="${API_URL:-http://localhost:8080}"
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-ledgerflow-postgres}"
LEDGER_CONTAINER="${LEDGER_CONTAINER:-ledgerflow-ledger-service}"
MAX_WAIT_SECONDS="${MAX_WAIT_SECONDS:-30}"
STAMP="$(date +%s)-$$"
EVENT_ID="evt-idempotency-${STAMP}"
TRANSACTION_ID="txn-idempotency-${STAMP}"
PAYLOAD="{\"event_id\":\"${EVENT_ID}\",\"transaction_id\":\"${TRANSACTION_ID}\",\"account_id\":\"ACC-IDEMPOTENCY\",\"type\":\"TRANSFER\",\"amount\":125,\"currency\":\"USD\",\"destination_account\":\"ACC-IDEMPOTENCY-DEST\"}"

# Git Bash users can set MSYS_NO_PATHCONV=1 on the Make command, without editing the student script.
query_count() {
  docker exec "${POSTGRES_CONTAINER}" psql -U ledgerflow -d ledgerflow -tAc "$1" | tr -d '\r[:space:]'
}
counts() {
  TX_COUNT="$(query_count "SELECT COUNT(*) FROM transactions WHERE event_id='${EVENT_ID}';")"
  ENTRY_COUNT="$(query_count "SELECT COUNT(*) FROM ledger_entries WHERE transaction_id='${TRANSACTION_ID}';")"
  PROCESSED_COUNT="$(query_count "SELECT COUNT(*) FROM processed_events WHERE event_id='${EVENT_ID}';")"
  printf 'transactions=%s ledger_entries=%s processed_events=%s\n' "${TX_COUNT}" "${ENTRY_COUNT}" "${PROCESSED_COUNT}"
}
assert_counts() {
  counts
  [[ "${TX_COUNT}" == "1" && "${ENTRY_COUNT}" == "2" && "${PROCESSED_COUNT}" == "1" ]]
}
submit() {
  curl --fail --show-error --silent --max-time 15 \
    -H 'Content-Type: application/json' --data "${PAYLOAD}" \
    "${API_URL}/api/v1/transactions" >/dev/null
}

echo "event_id=${EVENT_ID}"
echo "transaction_id=${TRANSACTION_ID}"
echo 'Baseline database counts:'
counts
if [[ "${TX_COUNT}" != "0" || "${ENTRY_COUNT}" != "0" || "${PROCESSED_COUNT}" != "0" ]]; then
  echo '✗ Identifiers unexpectedly exist; aborting without deleting data' >&2
  exit 1
fi

echo 'Step 1/2: Publish original event'
submit
first_ok=0
for ((seconds=0; seconds<MAX_WAIT_SECONDS; seconds++)); do
  if assert_counts; then first_ok=1; break; fi
  sleep 1
done
if [[ "$first_ok" != "1" ]]; then
  echo '✗ Original delivery did not reach expected database state in time' >&2
  exit 1
fi
echo '✓ First delivery persisted exactly one transaction, two ledger entries and one processed marker'

echo 'Step 2/2: Replay the identical payload'
submit
# A final DB count alone cannot prove that the consumer saw the replay.
# Look for the existing consumer's precise log message within a bounded window.
replay_seen=0
for ((seconds=0; seconds<MAX_WAIT_SECONDS; seconds++)); do
  if docker logs --since 2m "${LEDGER_CONTAINER}" 2>&1 | grep -Fq "duplicate event ignored: ${EVENT_ID}"; then
    replay_seen=1
    break
  fi
  sleep 1
done
if [[ "$replay_seen" != "1" ]]; then
  echo '✗ Replay not confirmed in Ledger Service logs; database alone does not prove delivery' >&2
  exit 1
fi
echo "✓ Ledger Service log confirmed: duplicate event ignored: ${EVENT_ID}"
echo 'Final database counts after replay:'
if ! assert_counts; then
  echo '✗ Duplicate replay changed expected database counts' >&2
  exit 1
fi
echo '✓ Duplicate event produced only one durable ledger transaction'
