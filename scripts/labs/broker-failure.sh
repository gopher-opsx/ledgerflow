#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-deployments/docker/compose.kafka.yaml}"
BROKER_CONTAINER="${BROKER_CONTAINER:-ledgerflow-broker-1}"
BOOTSTRAP_SERVER="${BOOTSTRAP_SERVER:-broker-1:19092}"
TOPIC="${TOPIC:-ledgerflow.transactions}"
FAILED_SERVICE="${FAILED_SERVICE:-broker-3}"

cleanup() {
    docker compose -f "${COMPOSE_FILE}" start "${FAILED_SERVICE}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

describe_topic() {
    docker exec "${BROKER_CONTAINER}" \
        /opt/kafka/bin/kafka-topics.sh \
        --bootstrap-server "${BOOTSTRAP_SERVER}" \
        --describe \
        --topic "${TOPIC}"
}

echo "Healthy topic state"
echo "==================="
describe_topic

echo
echo "Stopping ${FAILED_SERVICE}..."
docker compose -f "${COMPOSE_FILE}" stop "${FAILED_SERVICE}"
sleep 5

echo
echo "Topic state during broker failure"
echo "================================="
describe_topic

echo
echo "Restarting ${FAILED_SERVICE}..."
docker compose -f "${COMPOSE_FILE}" start "${FAILED_SERVICE}"

for attempt in {1..30}; do
    STATUS="$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "ledgerflow-${FAILED_SERVICE}" 2>/dev/null || true)"
    if [ "${STATUS}" = "healthy" ]; then
        break
    fi
    sleep 2
done

echo
echo "Recovered topic state"
echo "====================="
describe_topic

trap - EXIT
