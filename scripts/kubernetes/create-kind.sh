#!/usr/bin/env bash
# Creates the multi-node kind lab from the checked-in cluster configuration.
# Run from the repository root in Bash with the required lab services and tools available.
set -euo pipefail

kind create cluster --config deployments/kind/kind-config.yaml
kubectl cluster-info --context kind-ledgerflow
kubectl get nodes
