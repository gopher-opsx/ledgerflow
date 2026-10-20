#!/usr/bin/env bash
# Lesson 29: Remove only the ACL grants created by apply-acls.sh.
#
# This script does NOT:
# - Delete Kafka topics or messages
# - Remove Docker volumes
# - Change TLS or SASL configuration
# - Restart brokers or controllers
#
# Run only against the isolated LedgerFlow training cluster.

set -euo pipefail

BROKER=ledgerflow-broker-1
BOOTSTRAP=broker-1:19092
ADMIN=/etc/ledgerflow/sasl/admin.properties
PRINCIPAL=User:ledgerflow

echo "Removing LedgerFlow topic ACLs..."

for topic in \
  ledgerflow.transactions \
  ledgerflow.fraud-results \
  ledgerflow.notifications \
  ledgerflow.transactions.dlt
do
  MSYS_NO_PATHCONV=1 docker exec "${BROKER}" \
    /opt/kafka/bin/kafka-acls.sh \
    --bootstrap-server "${BOOTSTRAP}" \
    --command-config "${ADMIN}" \
    --remove --force \
    --allow-principal "${PRINCIPAL}" \
    --operation Read \
    --operation Write \
    --operation Describe \
    --topic "${topic}"
done

echo "Removing LedgerFlow consumer-group ACLs..."

for group in \
  ledger-service \
  fraud-service \
  notification-service
do
  MSYS_NO_PATHCONV=1 docker exec "${BROKER}" \
    /opt/kafka/bin/kafka-acls.sh \
    --bootstrap-server "${BOOTSTRAP}" \
    --command-config "${ADMIN}" \
    --remove --force \
    --allow-principal "${PRINCIPAL}" \
    --operation Read \
    --operation Describe \
    --group "${group}"
done

echo "LedgerFlow Lesson 29 ACL grants removed."