#!/usr/bin/env bash
# Removes two brokers and compares write behavior before and after recovery. A non-202 response alone does not establish the Kafka failure cause.
# Run from the repository root in Bash with the required lab services and tools available.
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-deployments/docker/compose.kafka.yaml}"
API_URL="${API_URL:-http://localhost:8080}"
BROKER_CONTAINER="${BROKER_CONTAINER:-ledgerflow-broker-1}"
BOOTSTRAP_SERVER="${BOOTSTRAP_SERVER:-broker-1:19092}"
TOPIC="${TOPIC:-ledgerflow.transactions}"

cleanup() {
    docker compose -f "${COMPOSE_FILE}" start broker-2 broker-3 >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Verifying topic durability configuration..."
docker exec "${BROKER_CONTAINER}" \
    /opt/kafka/bin/kafka-configs.sh \
    --bootstrap-server "${BOOTSTRAP_SERVER}" \
    --entity-type topics \
    --entity-name "${TOPIC}" \
    --describe

echo
echo "Stopping broker-2 and broker-3 so only one replica remains..."
docker compose -f "${COMPOSE_FILE}" stop broker-2 broker-3
sleep 5

STAMP="$(date +%s)"
HTTP_CODE="$(curl --silent --output /tmp/ledgerflow-producer-response.json --write-out '%{http_code}' \
    -H 'Content-Type: application/json' \
    --data "{\"event_id\":\"evt-reliability-${STAMP}\",\"transaction_id\":\"txn-reliability-${STAMP}\",\"account_id\":\"ACC-RELIABILITY\",\"type\":\"TRANSFER\",\"amount\":250,\"currency\":\"USD\",\"destination_account\":\"ACC-DEST\"}" \
    "${API_URL}/api/v1/transactions" || true)"

cat /tmp/ledgerflow-producer-response.json || true
echo

echo "HTTP status: ${HTTP_CODE}"
if [ "${HTTP_CODE}" = "202" ]; then
    echo "✗ Write unexpectedly succeeded with fewer than min.insync.replicas available"
    exit 1
fi

echo "✓ Write was rejected while the durability requirement could not be met"

echo
echo "Recovering brokers..."
docker compose -f "${COMPOSE_FILE}" start broker-2 broker-3
sleep 10

STAMP2="$(date +%s)"
HTTP_CODE="$(curl --silent --output /tmp/ledgerflow-producer-response-recovered.json --write-out '%{http_code}' \
    -H 'Content-Type: application/json' \
    --data "{\"event_id\":\"evt-reliability-recovered-${STAMP2}\",\"transaction_id\":\"txn-reliability-recovered-${STAMP2}\",\"account_id\":\"ACC-RELIABILITY\",\"type\":\"TRANSFER\",\"amount\":250,\"currency\":\"USD\",\"destination_account\":\"ACC-DEST\"}" \
    "${API_URL}/api/v1/transactions")"

cat /tmp/ledgerflow-producer-response-recovered.json
echo

if [ "${HTTP_CODE}" != "202" ]; then
    echo "✗ Write did not recover after ISR was restored"
    exit 1
fi

echo "✓ Write succeeded after the brokers recovered"
trap - EXIT
