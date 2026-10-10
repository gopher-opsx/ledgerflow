#!/usr/bin/env bash
# Deletes Compose persistent volumes and restarts the lab. This destroys existing Kafka and PostgreSQL lab data.
# Run from the repository root in Bash with the required lab services and tools available.

set -euo pipefail

COMPOSE_FILE="deployments/docker/compose.kafka.yaml"

echo "Stopping LedgerFlow and removing persistent volumes..."

docker compose \
    -f "${COMPOSE_FILE}" \
    down -v

echo
echo "Starting clean LedgerFlow environment..."

docker compose \
    -f "${COMPOSE_FILE}" \
    up -d

echo
echo "Waiting for Kafka..."

for attempt in {1..30}; do

    if docker exec ledgerflow-broker-1 sh -c \
        "/opt/kafka/bin/kafka-topics.sh \
        --bootstrap-server broker-1:19092 \
        --list" >/dev/null 2>&1; then

        echo "✓ Kafka ready"
        break
    fi

    if [ "${attempt}" -eq 30 ]; then
        echo "✗ Kafka did not become ready"
        exit 1
    fi

    sleep 2
done

./scripts/init-topics.sh

echo
echo "LedgerFlow reset complete."