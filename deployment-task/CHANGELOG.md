# Changelog

All notable changes follow [Keep a Changelog](https://keepachangelog.com/)
and [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-07-21
### Added
- Python stdlib HTTP demo app with `/`, `/healthz`, and `/metrics` endpoints.
- Slim Dockerfile with build-time version injection via APP_VERSION.
- kind cluster config with host port mappings (30080 -> 8080, 30030 -> 3000).
- Kubernetes Deployment (2 replicas, readiness probe) and NodePort Service.
- Terraform IaC for cluster provisioning.
- ArgoCD Application for GitOps auto-sync.
- Tag-driven GitHub Actions release pipeline pushing semver images to GHCR.
- Monitoring: kube-prometheus-stack via Helm + ServiceMonitor scraping the app.
