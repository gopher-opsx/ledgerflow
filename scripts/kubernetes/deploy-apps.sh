#!/usr/bin/env bash
# Applies the namespace, PostgreSQL, and application manifests to the current Kubernetes context.
# Run from the repository root in Bash with the required lab services and tools available.
set -euo pipefail

kubectl apply -f deployments/kubernetes/base/postgres.yaml
kubectl rollout status deployment/postgres -n ledgerflow --timeout=180s
kubectl apply -f deployments/kubernetes/base/apps.yaml
kubectl rollout status deployment/transaction-api -n ledgerflow --timeout=180s
kubectl rollout status deployment/ledger-service -n ledgerflow --timeout=180s
kubectl rollout status deployment/fraud-service -n ledgerflow --timeout=180s
kubectl rollout status deployment/notification-service -n ledgerflow --timeout=180s
kubectl get pods -n ledgerflow -o wide
