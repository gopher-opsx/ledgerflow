#!/usr/bin/env bash
set -euo pipefail

COMPOSE=(docker compose -f deployments/docker/compose.kafka.yaml -f deployments/docker/compose.mirrormaker.yaml)

"${COMPOSE[@]}" up -d mirror-broker mirrormaker2

echo "Waiting for mirrored cluster..."
for attempt in {1..30}; do
    if docker exec ledgerflow-mirror-broker \
        /opt/kafka/bin/kafka-topics.sh \
        --bootstrap-server mirror-broker:19093 \
        --list 2>/dev/null | grep -q '^ledgerflow.transactions$'; then
        echo "✓ ledgerflow.transactions is visible on the secondary cluster"
        docker exec ledgerflow-mirror-broker \
            /opt/kafka/bin/kafka-topics.sh \
            --bootstrap-server mirror-broker:19093 \
            --describe \
            --topic ledgerflow.transactions
        exit 0
    fi
    sleep 2
done

echo "✗ Mirrored topic did not appear within the expected window"
exit 1
