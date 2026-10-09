#!/usr/bin/env bash
set -euo pipefail

BROKER_CONTAINER="${BROKER_CONTAINER:-ledgerflow-broker-1}"
BOOTSTRAP_SERVER="${BOOTSTRAP_SERVER:-broker-1:19092}"
GROUP="${GROUP:-ledger-service}"
TOPIC="${TOPIC:-ledgerflow.transactions}"

KAFKA_BIN=/opt/kafka/bin

echo "Consumer groups"
echo "==============="
docker exec "${BROKER_CONTAINER}" \
    "${KAFKA_BIN}/kafka-consumer-groups.sh" \
    --bootstrap-server "${BOOTSTRAP_SERVER}" \
    --list

echo
echo "Consumer group: ${GROUP}"
echo "============================"
docker exec "${BROKER_CONTAINER}" \
    "${KAFKA_BIN}/kafka-consumer-groups.sh" \
    --bootstrap-server "${BOOTSTRAP_SERVER}" \
    --group "${GROUP}" \
    --describe

echo
echo "Topic: ${TOPIC}"
echo "============================"
docker exec "${BROKER_CONTAINER}" \
    "${KAFKA_BIN}/kafka-topics.sh" \
    --bootstrap-server "${BOOTSTRAP_SERVER}" \
    --describe \
    --topic "${TOPIC}"
