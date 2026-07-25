#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

CLUSTER="cardmarket-interview"
# ✅ Use :latest to get the newest version
IMAGE="ghcr.io/arun-singh-chauhan-09/interview-demo:latest"

# echo "==> 1/7 Pulling latest image from GHCR"
# docker pull "$IMAGE"

# echo "==> 2/7 Loading image into kind"
# kind load docker-image "$IMAGE" --name "$CLUSTER"

echo "==> 3/7 Deploying app"
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl rollout status deployment/demo-app --timeout=120s

echo "==> 4/7 Installing monitoring stack (this takes a few minutes)"
./monitoring/install.sh

echo "    waiting for Prometheus StatefulSet to be created..."
for i in {1..60}; do
  kubectl -n monitoring get statefulset prometheus-monitoring-kube-prometheus-prometheus >/dev/null 2>&1 && break
  sleep 5
done
kubectl -n monitoring rollout status statefulset/prometheus-monitoring-kube-prometheus-prometheus --timeout=300s

echo "==> 5/7 Registering app as a Prometheus scrape target"
kubectl apply -f k8s/servicemonitor.yaml

echo "==> 6/7 Applying alert rules (PrometheusRule)"
kubectl apply -f monitoring/demo-app-rules.yaml

echo "==> 7/7 Installing ArgoCD (GitOps)"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deployment/argocd-server --timeout=300s
kubectl apply -f argocd/application.yaml

# ─── Background port-forwards ───
echo "==> Starting port-forwards in the background"

declare -a PF_PIDS

start_pf () {
  local desc="$1"; shift
  kubectl port-forward "$@" >/dev/null 2>&1 &
  local pid=$!
  PF_PIDS+=("$pid")
  echo "    [$pid] $desc"
}

start_pf "app          -> localhost:8080"  -n default    svc/demo-app 8080:8080
start_pf "Grafana      -> localhost:3000"  -n monitoring svc/monitoring-grafana 3000:80
start_pf "Prometheus   -> localhost:9090"  -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
start_pf "Alertmanager -> localhost:9093"  -n monitoring svc/monitoring-kube-prometheus-alertmanager 9093:9093
start_pf "ArgoCD       -> localhost:8081"  -n argocd     svc/argocd-server 8081:443

# save PIDs so teardown can kill them cleanly
printf "%s\n" "${PF_PIDS[@]}" > /tmp/demo-portforwards.pids

# give forwards a moment, then verify each port is listening
sleep 4
echo
echo "==> Verifying port-forwards"
for pair in "8080:app" "3000:Grafana" "9090:Prometheus" "9093:Alertmanager" "8081:ArgoCD"; do
  port="${pair%%:*}"; name="${pair##*:}"
  if (echo > "/dev/tcp/127.0.0.1/$port") >/dev/null 2>&1; then
    echo "    ✅ $name listening on $port"
  else
    echo "    ⚠️  $name NOT reachable on $port — restart manually"
  fi
done

echo
echo "    ArgoCD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo

echo
echo "======================================================================"
echo " ✅ Done!  Endpoints:"
echo "======================================================================"
echo "  App:           http://localhost:8080         (curl localhost:8080/metrics)"
echo "  Grafana:       http://localhost:3000          (admin/admin)"
echo "  Prometheus:    http://localhost:9090/alerts   (filter: demo-app)"
echo "  Alertmanager:  http://localhost:9093"
echo "  ArgoCD:        https://localhost:8081         (admin / password above)"
echo
echo " Useful commands:"
echo "----------------------------------------------------------------------"
echo "  # App status / metrics"
echo "  curl localhost:8080/metrics"
echo "  kubectl get pods -n default"
echo
echo "  # ArgoCD / GitOps"
echo "  kubectl -n argocd get application demo-app -o wide"
echo
echo "  # ── Alerting demo ──"
echo "  # 1) pause GitOps self-heal so the app stays down"
echo "  kubectl patch application demo-app -n argocd --type merge \\"
echo "    -p '{\"spec\":{\"syncPolicy\":{\"automated\":{\"selfHeal\":false}}}}'"
echo
echo "  # 2) take the app down (watch localhost:9090/alerts go PENDING->FIRING)"
echo "  kubectl scale deploy/demo-app -n default --replicas=0"
echo
echo "  # 3) recover"
echo "  kubectl scale deploy/demo-app -n default --replicas=2"
echo
echo "  # 4) re-enable self-heal (back to clean GitOps state)"
echo "  kubectl patch application demo-app -n argocd --type merge \\"
echo "    -p '{\"spec\":{\"syncPolicy\":{\"automated\":{\"selfHeal\":true}}}}'"
echo
echo "  # ── Load generation (steady traffic for the rate graph) ──"
echo "  while true; do curl -s http://localhost:8080/ > /dev/null; sleep 0.2; done"
echo
echo "  # ── Stop all port-forwards ──"
echo "  pkill -f 'kubectl port-forward'"
echo "  # (PIDs also saved in /tmp/demo-portforwards.pids)"
echo "======================================================================"