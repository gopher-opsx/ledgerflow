#!/usr/bin/env bash
# LedgerFlow Lesson 26 — start the secondary Kafka broker and MirrorMaker 2.
# Run from the repository root: make mirrormaker-up
#
# This lab may need a few minutes on its FIRST run while Kafka Connect creates
# its internal topics and MirrorMaker discovers/creates the mirrored topics.
# Topic existence proves discovery/creation only; verify a new transaction on
# the secondary cluster separately to prove actual RECORD replication.
#
# Do not use "docker compose down -v" or "--remove-orphans" to prepare this lab:
# other lessons use the same Compose project and persistent volumes.
set -euo pipefail

COMPOSE=(docker compose \
    -f deployments/docker/compose.kafka.yaml \
    -f deployments/docker/compose.mirrormaker.yaml)

MIRROR_CONTAINER="ledgerflow-mirror-broker"
MM2_CONTAINER="ledgerflow-mirrormaker2"
BOOTSTRAP="mirror-broker:19093"
TOPIC="ledgerflow.transactions"

# Check every 3 seconds for up to 5 minutes (100 * 3 seconds).
# Users can adjust both values for slower machines.
MAX_ATTEMPTS=100
WAIT_SECONDS=3

printf 'Starting secondary Kafka broker and MirrorMaker 2...\n'
"${COMPOSE[@]}" up -d mirror-broker mirrormaker2

printf 'Waiting up to %s seconds for %s on the secondary cluster...\n' \
    "$((MAX_ATTEMPTS * WAIT_SECONDS))" "$TOPIC"

for ((attempt = 1; attempt <= MAX_ATTEMPTS; attempt++)); do
    # Check for an early MirrorMaker failure instead of hiding it as a timeout.
    mm2_status="$(docker inspect --format '{{.State.Status}}' "$MM2_CONTAINER" 2>/dev/null || true)"
    if [[ "$mm2_status" == "exited" || "$mm2_status" == "dead" ]]; then
        printf 'ERROR: MirrorMaker 2 is %s. Recent logs:\n' "$mm2_status" >&2
        docker logs --tail 60 "$MM2_CONTAINER" >&2 || true
        exit 1
    fi

    # MSYS_NO_PATHCONV stops Git Bash on Windows from modifying /opt/kafka paths.
    # Capture topic names first so the exact-name match remains reliable.
    topics="$(MSYS_NO_PATHCONV=1 docker exec "$MIRROR_CONTAINER" \
        /opt/kafka/bin/kafka-topics.sh \
        --bootstrap-server "$BOOTSTRAP" \
        --list 2>/dev/null || true)"

    if printf '%s\n' "$topics" | grep -Fxq "$TOPIC"; then
        printf 'SUCCESS: %s is visible on the secondary cluster.\n' "$TOPIC"
        MSYS_NO_PATHCONV=1 docker exec "$MIRROR_CONTAINER" \
            /opt/kafka/bin/kafka-topics.sh \
            --bootstrap-server "$BOOTSTRAP" \
            --describe --topic "$TOPIC"
        printf '\nNext: publish a NEW transaction through the primary API and find it on the secondary cluster.\n'
        exit 0
    fi

    if (( attempt % 10 == 0 )); then
        printf 'Still waiting (%s/%s checks); MirrorMaker status: %s\n' \
            "$attempt" "$MAX_ATTEMPTS" "${mm2_status:-unknown}"
    fi
    if (( attempt < MAX_ATTEMPTS )); then
        sleep "$WAIT_SECONDS"
    fi
done

printf 'ERROR: %s did not appear after approximately %s seconds.\n' \
    "$TOPIC" "$((MAX_ATTEMPTS * WAIT_SECONDS))" >&2
printf 'MirrorMaker 2 status:\n' >&2
docker ps -a --filter "name=$MM2_CONTAINER" >&2 || true
printf 'Last 60 MirrorMaker 2 log lines:\n' >&2
docker logs --tail 60 "$MM2_CONTAINER" >&2 || true
exit 1
