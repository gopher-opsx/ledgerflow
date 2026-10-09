#!/usr/bin/env bash
set -euo pipefail

for service in transaction-api ledger-service fraud-service notification-service; do
  docker build --build-arg SERVICE="${service}" -t "ledgerflow/${service}:local" -f Dockerfile .
  kind load docker-image --name ledgerflow "ledgerflow/${service}:local"
done
