#!/usr/bin/env bash
# Creates the banking topics used by the services. Existing topics are retained by --if-not-exists.
# Run from the repository root in Bash with the required lab services and tools available.
set -euo pipefail

BROKER_CONTAINER="${BROKER_CONTAINER:-ledgerflow-broker-1}"
BOOTSTRAP_SERVER="${BOOTSTRAP_SERVER:-broker-1:19092}"
PARTITIONS="${PARTITIONS:-3}"
REPLICATION_FACTOR="${REPLICATION_FACTOR:-3}"
MIN_ISR="${MIN_ISR:-2}"

wait_for_kafka() {
    echo "Waiting for Kafka..."
    for attempt in {1..30}; do
        if docker exec "${BROKER_CONTAINER}" \
            /opt/kafka/bin/kafka-broker-api-versions.sh \
            --bootstrap-server "${BOOTSTRAP_SERVER}" >/dev/null 2>&1; then
            echo "✓ Kafka is reachable"
            return 0
        fi
        sleep 2
    done

    echo "✗ Kafka did not become reachable"
    return 1
}

create_or_configure_topic() {
    local topic="$1"

    echo "Checking topic: ${topic}"

    if docker exec "${BROKER_CONTAINER}" \
        /opt/kafka/bin/kafka-topics.sh \
        --bootstrap-server "${BOOTSTRAP_SERVER}" \
        --list | grep -qx "${topic}"; then
        echo "✓ ${topic} already exists"
    else
        docker exec "${BROKER_CONTAINER}" \
            /opt/kafka/bin/kafka-topics.sh \
            --bootstrap-server "${BOOTSTRAP_SERVER}" \
            --create \
            --topic "${topic}" \
            --partitions "${PARTITIONS}" \
            --replication-factor "${REPLICATION_FACTOR}"
        echo "✓ ${topic} created"
    fi

    docker exec "${BROKER_CONTAINER}" \
        /opt/kafka/bin/kafka-configs.sh \
        --bootstrap-server "${BOOTSTRAP_SERVER}" \
        --entity-type topics \
        --entity-name "${topic}" \
        --alter \
        --add-config "min.insync.replicas=${MIN_ISR}" >/dev/null

    echo "✓ ${topic} configured with min.insync.replicas=${MIN_ISR}"
}

verify_topic() {
    local topic="$1"

    docker exec "${BROKER_CONTAINER}" \
        /opt/kafka/bin/kafka-topics.sh \
        --bootstrap-server "${BOOTSTRAP_SERVER}" \
        --describe \
        --topic "${topic}"
}

wait_for_kafka

create_or_configure_topic "ledgerflow.transactions"
create_or_configure_topic "ledgerflow.fraud-results"
create_or_configure_topic "ledgerflow.notifications"
create_or_configure_topic "ledgerflow.transactions.dlt"

echo
echo "LedgerFlow Kafka topics ready."
echo
verify_topic "ledgerflow.transactions"
