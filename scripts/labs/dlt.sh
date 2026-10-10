#!/usr/bin/env bash
# Publishes malformed JSON and looks for the same payload on the ledger dead-letter topic.
# Run from the repository root in Bash with the required lab services and tools available.
set -euo pipefail

BROKER_CONTAINER="${BROKER_CONTAINER:-ledgerflow-broker-1}"
BOOTSTRAP_SERVER="${BOOTSTRAP_SERVER:-broker-1:19092}"
STAMP="$(date +%s)"
BAD_RECORD="not-json-${STAMP}"

printf '%s\n' "${BAD_RECORD}" | docker exec -i "${BROKER_CONTAINER}" \
    /opt/kafka/bin/kafka-console-producer.sh \
    --bootstrap-server "${BOOTSTRAP_SERVER}" \
    --topic ledgerflow.transactions >/dev/null

echo "✓ Published malformed event"
sleep 3

DLT_MESSAGES="$(docker exec "${BROKER_CONTAINER}" \
    /opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server "${BOOTSTRAP_SERVER}" \
    --topic ledgerflow.transactions.dlt \
    --from-beginning \
    --timeout-ms 5000 2>/dev/null || true)"

if ! echo "${DLT_MESSAGES}" | grep -q "${BAD_RECORD}"; then
    echo "✗ Malformed event was not found on the DLT"
    exit 1
fi

echo "✓ Malformed event routed to ledgerflow.transactions.dlt"
