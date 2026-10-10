#!/usr/bin/env bash
# Builds local application images and loads them into the kind cluster; no remote registry is required.
# Run from the repository root in Bash with the required lab services and tools available.
set -euo pipefail

for service in transaction-api ledger-service fraud-service notification-service; do
  docker build --build-arg SERVICE="${service}" -t "ledgerflow/${service}:local" -f Dockerfile .
  kind load docker-image --name ledgerflow "ledgerflow/${service}:local"
done
