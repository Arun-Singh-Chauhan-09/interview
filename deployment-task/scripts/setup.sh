#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

CLUSTER="cardmarket-interview"
# ✅ Use :latest to get the newest version
IMAGE="ghcr.io/arun-singh-chauhan-09/interview-demo:latest"

# echo "==> 1/6 Pulling latest image from GHCR"
# docker pull "$IMAGE"

# echo "==> 2/6 Loading image "
# kind load docker-image "$IMAGE" --name "$CLUSTER"into kind

echo "==> 3/6 Deploying app"
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl rollout status deployment/demo-app --timeout=120s

echo "==> 4/6 Installing monitoring stack (this takes a few minutes)"
./monitoring/install.sh

echo "    waiting for Prometheus StatefulSet to be created..."
for i in {1..60}; do
  kubectl -n monitoring get statefulset prometheus-monitoring-kube-prometheus-prometheus >/dev/null 2>&1 && break
  sleep 5
done
kubectl -n monitoring rollout status statefulset/prometheus-monitoring-kube-prometheus-prometheus --timeout=300s

echo "==> 5/6 Registering app as a Prometheus scrape target"
kubectl apply -f k8s/servicemonitor.yaml

echo "==> 6/6 Installing ArgoCD (GitOps)"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deployment/argocd-server --timeout=300s
kubectl apply -f argocd/application.yaml

echo
echo "✅ Done! Verify with:"
echo "  curl localhost:8080"
echo "  kubectl -n argocd get application demo-app -o wide"
echo "  Grafana:  http://localhost:3000  (admin/admin)"