#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-deployments/docker/compose.kafka.yaml}"
API_URL="${API_URL:-http://localhost:8080}"
BROKER_CONTAINER="${BROKER_CONTAINER:-ledgerflow-broker-1}"
BOOTSTRAP_SERVER="${BOOTSTRAP_SERVER:-broker-1:19092}"
COUNT="${COUNT:-30}"

cleanup() {
    docker compose -f "${COMPOSE_FILE}" start ledger-service >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Stopping ledger-service to create consumer lag..."
docker compose -f "${COMPOSE_FILE}" stop ledger-service

STAMP="$(date +%s)"
for i in $(seq 1 "${COUNT}"); do
    curl --fail --silent \
        -H "Content-Type: application/json" \
        --data "{\"event_id\":\"evt-lag-${STAMP}-${i}\",\"transaction_id\":\"txn-lag-${STAMP}-${i}\",\"account_id\":\"ACC-LAG-$((i % 3 + 1))\",\"type\":\"TRANSFER\",\"amount\":$((100 + i)),\"currency\":\"USD\",\"destination_account\":\"ACC-LAG-DEST\"}" \
        "${API_URL}/api/v1/transactions" >/dev/null
done

echo "✓ Produced ${COUNT} transactions while ledger-service was stopped"
echo

echo "Lag while consumer is stopped:"
docker exec "${BROKER_CONTAINER}" \
    /opt/kafka/bin/kafka-consumer-groups.sh \
    --bootstrap-server "${BOOTSTRAP_SERVER}" \
    --group ledger-service \
    --describe

echo
echo "Restarting ledger-service..."
docker compose -f "${COMPOSE_FILE}" start ledger-service

echo "Waiting for lag to recover..."
for attempt in {1..30}; do
    OUTPUT="$(docker exec "${BROKER_CONTAINER}" \
        /opt/kafka/bin/kafka-consumer-groups.sh \
        --bootstrap-server "${BOOTSTRAP_SERVER}" \
        --group ledger-service \
        --describe 2>/dev/null || true)"

    echo "${OUTPUT}"

    TOTAL_LAG="$(echo "${OUTPUT}" | awk 'NR>2 && $6 ~ /^[0-9]+$/ {sum += $6} END {print sum+0}')"
    if [ "${TOTAL_LAG}" = "0" ]; then
        echo "✓ Consumer lag recovered to zero"
        trap - EXIT
        exit 0
    fi

    sleep 2
done

echo "✗ Consumer lag did not recover within the expected window"
exit 1
