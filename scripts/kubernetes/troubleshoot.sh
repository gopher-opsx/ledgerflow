#!/usr/bin/env bash
set -euo pipefail

kubectl get nodes
kubectl get pods -n ledgerflow -o wide
kubectl get kafka,kafkanodepool,kafkatopic -n ledgerflow
kubectl get events -n ledgerflow --sort-by=.lastTimestamp | tail -30
