#!/usr/bin/env bash
# Creates and populates separate retention and compaction demonstration topics. Cleanup happens asynchronously.
# Run from the repository root in Bash with the required lab services and tools available.
set -euo pipefail

BROKER_CONTAINER="${BROKER_CONTAINER:-ledgerflow-broker-1}"
BOOTSTRAP_SERVER="${BOOTSTRAP_SERVER:-broker-1:19092}"
RETENTION_TOPIC="${RETENTION_TOPIC:-ledgerflow.retention-demo}"
COMPACTION_TOPIC="${COMPACTION_TOPIC:-ledgerflow.compaction-demo}"

create_topic() {
    local topic="$1"
    docker exec "${BROKER_CONTAINER}" \
        /opt/kafka/bin/kafka-topics.sh \
        --bootstrap-server "${BOOTSTRAP_SERVER}" \
        --create \
        --if-not-exists \
        --topic "${topic}" \
        --partitions 1 \
        --replication-factor 3 >/dev/null
}

create_topic "${RETENTION_TOPIC}"
create_topic "${COMPACTION_TOPIC}"

docker exec "${BROKER_CONTAINER}" \
    /opt/kafka/bin/kafka-configs.sh \
    --bootstrap-server "${BOOTSTRAP_SERVER}" \
    --entity-type topics \
    --entity-name "${RETENTION_TOPIC}" \
    --alter \
    --add-config cleanup.policy=delete,retention.ms=60000 >/dev/null

docker exec "${BROKER_CONTAINER}" \
    /opt/kafka/bin/kafka-configs.sh \
    --bootstrap-server "${BOOTSTRAP_SERVER}" \
    --entity-type topics \
    --entity-name "${COMPACTION_TOPIC}" \
    --alter \
    --add-config cleanup.policy=compact,min.cleanable.dirty.ratio=0.01,segment.ms=60000 >/dev/null

echo "Retention topic configuration"
docker exec "${BROKER_CONTAINER}" \
    /opt/kafka/bin/kafka-configs.sh \
    --bootstrap-server "${BOOTSTRAP_SERVER}" \
    --entity-type topics \
    --entity-name "${RETENTION_TOPIC}" \
    --describe

echo
echo "Compaction topic configuration"
docker exec "${BROKER_CONTAINER}" \
    /opt/kafka/bin/kafka-configs.sh \
    --bootstrap-server "${BOOTSTRAP_SERVER}" \
    --entity-type topics \
    --entity-name "${COMPACTION_TOPIC}" \
    --describe

echo
echo "Producing retention demo records..."
printf 'one\ntwo\nthree\nfour\nfive\n' | docker exec -i "${BROKER_CONTAINER}" \
    /opt/kafka/bin/kafka-console-producer.sh \
    --bootstrap-server "${BOOTSTRAP_SERVER}" \
    --topic "${RETENTION_TOPIC}"

echo "Producing keyed compaction demo records..."
printf 'ACC-1001:balance=100\nACC-1002:balance=200\nACC-1001:balance=150\nACC-1002:balance=250\nACC-1001:balance=175\n' | docker exec -i "${BROKER_CONTAINER}" \
    /opt/kafka/bin/kafka-console-producer.sh \
    --bootstrap-server "${BOOTSTRAP_SERVER}" \
    --topic "${COMPACTION_TOPIC}" \
    --property parse.key=true \
    --property key.separator=:

echo
echo "✓ Demo topics configured and populated"
echo "Note: retention deletion and compaction are asynchronous background operations."
