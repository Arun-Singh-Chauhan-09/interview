#!/usr/bin/env bash
set -euo pipefail

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install monitoring \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --values monitoring/values.yaml

echo "Grafana: http://localhost:3000  (admin / admin)"
echo "Prometheus should show demo-app as UP within ~30s"
