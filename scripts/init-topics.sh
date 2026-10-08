#!/usr/bin/env bash

set -euo pipefail

BROKER_CONTAINER="ledgerflow-broker-1"
BOOTSTRAP_SERVER="broker-1:19092"

create_topic() {
    local topic="$1"

    echo "Checking topic: ${topic}"

    if docker exec "${BROKER_CONTAINER}" sh -c \
        "/opt/kafka/bin/kafka-topics.sh \
        --bootstrap-server ${BOOTSTRAP_SERVER} \
        --list" | grep -qx "${topic}"; then

        echo "✓ ${topic} already exists"
        return
    fi

    docker exec "${BROKER_CONTAINER}" sh -c \
        "/opt/kafka/bin/kafka-topics.sh \
        --bootstrap-server ${BOOTSTRAP_SERVER} \
        --create \
        --topic ${topic} \
        --partitions 3 \
        --replication-factor 3"

    echo "✓ ${topic} created"
}

create_topic "ledgerflow.transactions"
create_topic "ledgerflow.fraud-results"
create_topic "ledgerflow.notifications"

echo
echo "LedgerFlow Kafka topics ready."