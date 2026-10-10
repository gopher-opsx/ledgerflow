#!/usr/bin/env bash
# Installs the Strimzi operator and Kafka resources for the Kubernetes lab.
# Run from the repository root in Bash with the required lab services and tools available.
set -euo pipefail

kubectl apply -f deployments/kubernetes/base/namespace.yaml
kubectl create namespace strimzi-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create -f 'https://strimzi.io/install/latest?namespace=strimzi-system' -n strimzi-system
kubectl wait deployment/strimzi-cluster-operator -n strimzi-system --for=condition=Available --timeout=300s
kubectl apply -f deployments/kubernetes/strimzi/kafka.yaml
kubectl wait kafka/ledgerflow -n ledgerflow --for=condition=Ready --timeout=600s
kubectl apply -f deployments/kubernetes/strimzi/topics.yaml
