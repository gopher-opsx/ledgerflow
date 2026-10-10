#!/usr/bin/env bash
# Collects Kubernetes workload evidence for the lab. Review the selected context before running.
# Run from the repository root in Bash with the required lab services and tools available.
set -euo pipefail

kubectl get nodes
kubectl get pods -n ledgerflow -o wide
kubectl get kafka,kafkanodepool,kafkatopic -n ledgerflow
kubectl get events -n ledgerflow --sort-by=.lastTimestamp | tail -30
