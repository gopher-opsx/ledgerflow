#!/usr/bin/env bash
# Register or update the LedgerFlow PostgreSQL CDC connector through Kafka Connect.
# Run from the LedgerFlow repository root after Kafka, PostgreSQL, and Kafka Connect are started.
# The worker can accept a connector before its task is ready, so verify RUNNING status with retries.
set -euo pipefail

CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"
CONFIG_FILE="${CONFIG_FILE:-deployments/integration/connect/postgres-connector.json}"
CONNECTOR_NAME="ledgerflow-postgres-cdc"
STATUS_URL="${CONNECT_URL}/connectors/${CONNECTOR_NAME}/status"

# Stop early if the local connector JSON is missing or malformed.
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "✗ Missing connector configuration: $CONFIG_FILE" >&2
    exit 1
fi
python3 - "$CONFIG_FILE" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as file:
    document = json.load(file)
if not isinstance(document.get("config"), dict) or document.get("name") != "ledgerflow-postgres-cdc":
    sys.exit("Connector JSON must contain the expected name and config object")
PY

wait_for_connect() {
    echo "Waiting for Kafka Connect..."
    for attempt in {1..60}; do
        if curl --fail --silent --show-error --max-time 5 \
            "${CONNECT_URL}/connectors" >/dev/null 2>&1; then
            echo "✓ Kafka Connect REST API is ready"
            return 0
        fi
        sleep 2
    done
    echo "✗ Kafka Connect REST API did not become ready" >&2
    return 1
}

wait_for_connector() {
    echo "Waiting for Debezium connector and task to reach RUNNING..."
    local response state
    for attempt in {1..60}; do
        # A freshly registered connector may briefly return an HTTP error while Connect rebalances.
        if response="$(curl --fail --silent --show-error --max-time 5 "$STATUS_URL" 2>/dev/null)"; then
            state="$(printf '%s' "$response" | python3 -c '
import json, sys
try:
    info = json.load(sys.stdin)
    connector = info.get("connector", {}).get("state")
    tasks = info.get("tasks", [])
    states = [task.get("state") for task in tasks]
    if connector == "FAILED" or "FAILED" in states:
        print("FAILED")
    elif connector == "RUNNING" and states and all(s == "RUNNING" for s in states):
        print("RUNNING")
    else:
        print("PENDING")
except (ValueError, TypeError, AttributeError):
    print("PENDING")
')"
            case "$state" in
                RUNNING)
                    echo "✓ Debezium connector and task are RUNNING"
                    printf '%s\n' "$response"
                    return 0 ;;
                FAILED)
                    echo "✗ Debezium connector or task has FAILED:" >&2
                    printf '%s\n' "$response" >&2
                    return 1 ;;
            esac
        fi
        sleep 2
    done
    echo "✗ Timed out waiting for Debezium connector and task to reach RUNNING" >&2
    echo "Inspect status: curl -i '$STATUS_URL'" >&2
    return 1
}

wait_for_connect

if curl --fail --silent --max-time 5 \
    "${CONNECT_URL}/connectors/${CONNECTOR_NAME}" >/dev/null 2>&1; then
    echo "Updating ${CONNECTOR_NAME}..."
    # PUT /config expects the inner config object, not the outer {name,config} wrapper.
    python3 - "$CONFIG_FILE" <<'PY' | curl --fail --silent --show-error \
        -X PUT -H 'Content-Type: application/json' --data-binary @- \
        "${CONNECT_URL}/connectors/${CONNECTOR_NAME}/config" >/dev/null
import json, sys
with open(sys.argv[1], encoding="utf-8") as file:
    print(json.dumps(json.load(file)["config"]))
PY
else
    echo "Creating ${CONNECTOR_NAME}..."
    # POST /connectors expects the full JSON document with both name and config.
    curl --fail --silent --show-error -X POST \
        -H 'Content-Type: application/json' \
        --data-binary "@${CONFIG_FILE}" \
        "${CONNECT_URL}/connectors" >/dev/null
fi

echo "✓ Debezium configuration submitted"
wait_for_connector
