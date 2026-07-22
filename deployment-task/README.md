# Cardmarket interview — build task

Local Kubernetes build/release/deploy demo. A small Python HTTP app is built
into a container, released automatically on version tags, deployed to a local
kind cluster via GitOps, and monitored with Prometheus + Grafana.

## Stack
- App: Python standard library HTTP server (no dependencies), exposes /metrics
- Container: slim Python base, non-root, version injected at build
- Cluster: kind (local, no cloud provider)
- IaC: Terraform provisions the cluster
- CI/CD: GitHub Actions, tag-driven, pushes semver images to GHCR
- GitOps: ArgoCD syncs k8s/ manifests to the cluster
- Monitoring: kube-prometheus-stack (Helm) + ServiceMonitor
- Versioning: SemVer via git tags; CHANGELOG.md tracks releases

## Quickstart
    # 1. cluster
    cd terraform && terraform init && terraform apply -auto-approve && cd ..
    # (or: kind create cluster --config kind-config.yaml)

    # 2. build + load locally for first run
    docker build -t ghcr.io/Arun-Singh-Chauhan-09/cardmarket-demo:0.1.0 --build-arg VERSION=0.1.0 ./app
    kind load docker-image ghcr.io/Arun-Singh-Chauhan-09/cardmarket-demo:0.1.0 --name cardmarket-interview

    # 3. GitOps
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    kubectl apply -f argocd/application.yaml

    # 4. monitoring
    ./monitoring/install.sh
    kubectl apply -f k8s/servicemonitor.yaml

    # 5. verify
    curl localhost:8080        # app
    curl localhost:8080/metrics
    # Grafana at http://localhost:3000 (admin / admin)

## Release flow
    git tag v0.1.1 && git push origin v0.1.1   # CI builds + pushes image, cuts release
    # bump image tag in k8s/deployment.yaml, push -> ArgoCD auto-syncs

## Port symmetry
    app listens 8080  ==  containerPort 8080  ==  Service targetPort 8080
    Service nodePort 30080  ==  kind mapping 30080  ->  localhost:8080
    Grafana nodePort 30030  ==  kind mapping 30030  ->  localhost:3000

## Design decisions
- kind over minikube/k3s: fast, disposable, config-as-code, CI-friendly.
- stdlib over FastAPI: zero deps keeps the focus on the DevOps layer.
- Terraform owns the cluster; ArgoCD owns the app manifests — clean separation.
- Tag-driven releases give reproducible, SemVer-aligned images.
- Monitoring added as an extra: it's how I'd actually run this in production.

Remember: work in your own fork, do NOT open a PR against the source repo.
