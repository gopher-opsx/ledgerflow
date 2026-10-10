#!/usr/bin/env bash
# Registers the PostgreSQL CDC connector with Kafka Connect. Requires the integration services to be running.
# Run from the repository root in Bash with the required lab services and tools available.
set -euo pipefail

CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"
CONFIG_FILE="${CONFIG_FILE:-deployments/integration/connect/postgres-connector.json}"
CONNECTOR_NAME="ledgerflow-postgres-cdc"

wait_for_connect() {
    echo "Waiting for Kafka Connect..."
    for attempt in {1..60}; do
        if curl --fail --silent "${CONNECT_URL}/connectors" >/dev/null 2>&1; then
            echo "✓ Kafka Connect is ready"
            return 0
        fi
        sleep 2
    done
    echo "✗ Kafka Connect did not become ready"
    return 1
}

wait_for_connect

if curl --fail --silent "${CONNECT_URL}/connectors/${CONNECTOR_NAME}" >/dev/null 2>&1; then
    echo "Updating ${CONNECTOR_NAME}..."
    python3 - "${CONFIG_FILE}" <<'PY' | curl --fail --silent -X PUT \
        -H 'Content-Type: application/json' \
        --data-binary @- \
        "${CONNECT_URL}/connectors/ledgerflow-postgres-cdc/config" >/dev/null
import json,sys
with open(sys.argv[1]) as f:
    print(json.dumps(json.load(f)["config"]))
PY
else
    echo "Creating ${CONNECTOR_NAME}..."
    curl --fail --silent -X POST \
        -H 'Content-Type: application/json' \
        --data-binary "@${CONFIG_FILE}" \
        "${CONNECT_URL}/connectors" >/dev/null
fi

echo "✓ Debezium connector configured"
curl --fail --silent "${CONNECT_URL}/connectors/${CONNECTOR_NAME}/status"
echo
