#!/usr/bin/env bash
# Adds topic and consumer-group permissions for the lab principal using the mounted admin credentials.
# Run from the repository root in Bash with the required lab services and tools available.
set -euo pipefail

BROKER=ledgerflow-broker-1
BOOTSTRAP=broker-1:19092
ADMIN=/etc/ledgerflow/sasl/admin.properties

for topic in ledgerflow.transactions ledgerflow.fraud-results ledgerflow.notifications ledgerflow.transactions.dlt; do
  docker exec "${BROKER}" /opt/kafka/bin/kafka-acls.sh \
    --bootstrap-server "${BOOTSTRAP}" \
    --command-config "${ADMIN}" \
    --add --allow-principal User:ledgerflow \
    --operation Read --operation Write --operation Describe \
    --topic "${topic}"
done

for group in ledger-service fraud-service notification-service; do
  docker exec "${BROKER}" /opt/kafka/bin/kafka-acls.sh \
    --bootstrap-server "${BOOTSTRAP}" \
    --command-config "${ADMIN}" \
    --add --allow-principal User:ledgerflow \
    --operation Read --operation Describe \
    --group "${group}"
done

echo "✓ LedgerFlow topic and consumer-group ACLs applied"
