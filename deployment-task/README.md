# Cardmarket interview — build task

Local Kubernetes build/release/deploy demo. A small Python HTTP app is built into a
container, released automatically on version tags, deployed to a local kind cluster
via GitOps, and monitored with a full metrics/alerting/logs stack.

## Stack

- **App**: Python standard library HTTP server (no dependencies), exposes `/metrics`
- **Container**: slim Python base, non-root, version injected at build
- **Cluster**: kind (local, no cloud provider)
- **IaC**: Terraform provisions the cluster
- **CI/CD**: GitHub Actions, tag-driven, pushes semver images to GHCR
- **GitOps**: ArgoCD syncs `k8s/` manifests to the cluster
- **Monitoring**: kube-prometheus-stack (Helm) + ServiceMonitor + Alertmanager
- **Logging**: Loki + Promtail (loki-stack)
- **Versioning**: SemVer via git tags; `CHANGELOG.md` tracks releases

## Quickstart

The whole stack — app, monitoring, alerting, logs, and ArgoCD — comes up with one script.

```bash
# 1. cluster
cd terraform && terraform init && terraform apply -auto-approve && cd ..

# 2. everything else (app + monitoring + alerting + logs + ArgoCD)
cd scripts && bash setup.sh
```

`setup.sh` finishes by starting background port-forwards and printing every endpoint
plus the ArgoCD admin password. To tear it all down:

```bash
bash scripts/teardown.sh   # stops forwards, re-enables self-heal, destroys the cluster
```

## Release flow

```bash
git tag v0.1.1 && git push origin v0.1.1   # CI builds + pushes image, cuts release
# bump image tag in k8s/deployment.yaml, push -> ArgoCD auto-syncs
```

## Port symmetry

```
app listens 8080  ==  containerPort 8080  ==  Service targetPort 8080
Service nodePort 30080  ==  kind mapping 30080  ->  localhost:8080
Grafana nodePort 30030  ==  kind mapping 30030  ->  localhost:3000
```

## Design decisions

- **kind over minikube/k3s**: fast, disposable, config-as-code, CI-friendly.
- **stdlib over FastAPI**: zero deps keeps the focus on the DevOps layer.
- **Terraform owns the cluster; ArgoCD owns the app manifests** — clean separation.
- **Tag-driven releases** give reproducible, SemVer-aligned images.
- **Monitoring, alerting, and logging** added as an extra: it's how I'd actually run
  this in production.

---

# Observability

This project runs a full three-pillar observability stack on the local kind cluster,
provisioned declaratively and reproducible with a single script.

## Architecture

```mermaid
graph TB
    dev["Developer host (WSL2)<br/>kubectl · browser · port-forwards"]
    gitrepo["Git repo<br/>(app manifests)"]

    dev -->|terraform apply<br/>provisions| cluster

    subgraph cluster["kind cluster (Terraform-provisioned)"]
        subgraph nsApp["namespace: default"]
            svc["Service: demo-app"]
            app["demo-app<br/>FastAPI, 2 replicas<br/>/metrics + stdout logs"]
            svc --> app
        end
        subgraph nsArgo["namespace: argocd"]
            argo["ArgoCD<br/>GitOps auto-sync + self-heal"]
        end
        subgraph nsMon["namespace: monitoring"]
            prom["Prometheus<br/>scrapes /metrics"]
            rules["PrometheusRule<br/>DemoAppReplicaDown / AllDown"]
            am["Alertmanager<br/>routes by severity"]
            loki["Loki<br/>log store"]
            pt["Promtail<br/>DaemonSet"]
            graf["Grafana<br/>Prometheus + Loki datasources"]
        end
    end

    gitrepo -->|desired state| argo
    argo -->|deploys / reconciles| app
    prom -->|scrape :8080/metrics| svc
    prom --> rules
    rules -->|fires| am
    pt -.->|reads stdout| app
    pt -->|ships logs| loki
    graf -->|PromQL| prom
    graf -->|LogQL| loki
    dev -.->|:3000 :9090 :9093 :8081| graf
```

*(Full diagram source in [`architecture.mmd`](architecture.mmd).)*

## The three pillars

| Pillar | Component | Role |
| --- | --- | --- |
| **Metrics** | Prometheus + Grafana | Scrapes the app's `/metrics` endpoint; visualised in Grafana |
| **Alerting** | Alertmanager + PrometheusRule | Fires on pod-down, routes by severity |
| **Logs** | Loki + Promtail | Promtail tails pod stdout from the node, ships to Loki; queried in Grafana |

All three are installed by `scripts/setup.sh` and configured via version-controlled
Helm values (`monitoring/values.yaml`, `monitoring/loki-values.yaml`) — no manual UI
steps required.

## Lifecycle

```bash
# 1. create the cluster (Terraform-managed kind)
cd deployment-task/terraform && terraform apply

# 2. deploy app + monitoring + alerting + logs + ArgoCD
cd ../scripts && bash setup.sh

# 3. tear everything down (stops forwards, destroys cluster)
bash teardown.sh
```

## Endpoints

| Service | URL | Notes |
| --- | --- | --- |
| App | http://localhost:8080 | `curl localhost:8080/metrics` |
| Grafana | http://localhost:3000 | admin / admin |
| Prometheus | http://localhost:9090/alerts | filter: `demo-app` |
| Alertmanager | http://localhost:9093 | |
| ArgoCD | https://localhost:8081 | admin / (password from setup output) |

## Key queries

**Metrics (Prometheus datasource):**
```promql
up{job="demo-app"}                                            # per-pod liveness
sum(rate(app_requests_total{job="demo-app"}[5m]))             # request rate (req/s)
sum(rate(app_requests_total{job="demo-app"}[5m])) by (pod)    # per-pod rate
```

**Logs (Loki datasource):**
```logql
{namespace="default", app="demo-app"}                # stream app logs
sum(rate({app="demo-app"}[5m]))                       # request rate from log volume
```

## Alerting demo

```bash
# 1. pause GitOps self-heal (else ArgoCD reconciles the app back up)
kubectl patch application demo-app -n argocd --type merge \
  -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":false}}}}'

# 2. take the app down — watch localhost:9090/alerts go PENDING -> FIRING
kubectl scale deploy/demo-app -n default --replicas=0

# 3. observe the alert routed to the "critical" receiver in Alertmanager (:9093)

# 4. recover + restore GitOps state
kubectl scale deploy/demo-app -n default --replicas=2
kubectl patch application demo-app -n argocd --type merge \
  -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":true}}}}'
```

The `for:` clause on each rule debounces transient blips (e.g. rolling restarts) so
only sustained outages page.

## Design notes

- **App logs to stdout**; Promtail collects from the node's `/var/log/pods`. The app
  never manages log files — the platform collects. This is the standard cloud-native
  logging pattern.
- **Counters are summed across pods and wrapped in `rate()`** — each replica holds its
  own counter, and `rate()` handles counter resets on restart.
- **Datasources are provisioned declaratively** via Helm values, with Prometheus as the
  sole default (Loki `isDefault: false`) to avoid provisioning conflicts.
- **Demo-scoped trade-offs**: Loki uses filesystem storage (no object store), Prometheus
  retention is 2h, and resources are minimal. Production would use object storage, longer
  retention, HA, and the current Loki + Alloy chart in place of the deprecated `loki-stack`.

---


