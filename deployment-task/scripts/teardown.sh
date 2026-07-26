#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."

echo "==> 1/3 Stopping background port-forwards"
if [ -f /tmp/demo-portforwards.pids ]; then
  while read -r pid; do
    [ -n "$pid" ] && kill "$pid" >/dev/null 2>&1 && echo "    killed PID $pid"
  done < /tmp/demo-portforwards.pids
  rm -f /tmp/demo-portforwards.pids
fi
# blunt fallback in case the PID file is stale or missing
pkill -f 'kubectl port-forward' >/dev/null 2>&1 || true
echo "    all kubectl port-forwards stopped"

echo "==> 2/3 Re-enabling ArgoCD self-heal (if the app still exists)"
kubectl patch application demo-app -n argocd --type merge \
  -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":true}}}}' >/dev/null 2>&1 \
  && echo "    self-heal re-enabled" \
  || echo "    demo-app not found (already torn down) — skipping"

echo "==> 3/3 Destroying the kind cluster (terraform)"
cd terraform
terraform destroy -auto-approve

echo
echo "✅ Teardown complete."
echo "   Verify nothing is left:  docker ps"