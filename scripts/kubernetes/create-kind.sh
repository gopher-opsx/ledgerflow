#!/usr/bin/env bash
set -euo pipefail

kind create cluster --config deployments/kind/kind-config.yaml
kubectl cluster-info --context kind-ledgerflow
kubectl get nodes
