#!/usr/bin/env bash
# Starts Connect, registry, and Streams by merging the integration overlay with the base Compose file.
# Run from the repository root in Bash with the required lab services and tools available.
set -euo pipefail

docker compose \
  -f deployments/docker/compose.kafka.yaml \
  -f deployments/docker/compose.integration.yaml \
  up -d --build kafka-connect schema-registry schema-registry-ui streams-service

echo "Integration profile started."
echo "Kafka Connect:    http://localhost:8083"
echo "Schema Registry:  http://localhost:8085"
echo "Registry UI:      http://localhost:8888"
