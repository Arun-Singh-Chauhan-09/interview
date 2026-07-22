# Submission — Arun Singh Chauhan

## Contents

| Task | Location |
|---|---|
| k8s deployment | [`deployment-task/`](deployment-task/) |
| Shell script review | [`REVIEW-shell.md`](REVIEW-shell.md) |
| Deployment review | [`REVIEW-k8s.md`](REVIEW-k8s.md) |

## Build task summary

A Python HTTP app built into a container, released automatically on version
tags, deployed to a local kind cluster via GitOps, and monitored with
Prometheus and Grafana.

- **Cluster** — kind, provisioned by Terraform (`deployment-task/terraform/`)
- **App** — Python stdlib HTTP server, own Dockerfile, non-root
- **Release** — tag-driven GitHub Actions → semver image on GHCR
- **Deploy** — ArgoCD syncs `deployment-task/k8s/` to the cluster
- **Monitoring** — kube-prometheus-stack + ServiceMonitor scraping the app
- **Reproducible** — `terraform apply` then `./deployment-task/scripts/setup.sh`
  rebuilds the whole environment from scratch

Full details in [`deployment-task/README.md`](deployment-task/README.md).

---

*(Original task description below.)*


# Interviews

## This repo contains tasks we request interviewees to complete

* This repository should be forked, candidates should work in their own forked versions.
Please don't open pull requests with solutions agains this repository.
* No tasks require the use of any paid services.
* For all of the following tasks please use your favourite tools.
* During the interview the interviewee guides us through
their solution. Explaining decisions and technical concepts as we go.
* Tasks can be solved in a very simplistic way or as complicated as you can imagine.
Both can be valid.

### k8s deployment

* please don't use cloud infra providers like AWS, GCP etc. The cluster should
be a local one.
  
1. Set up a kubernetes cluster ie. kind, minikube, k3s etc.
the one you like the most.
2. Build and release an app. This application should have a dockerfile created
by you and it should be built by you. This can be something very simple,
ie traefik/whoami, hashicorp/http-echo, your own if you have one.
Each release should happen automatically.
3. Create a deployment of this app.

* extras: IaC, GitOps, semver, changelog

### review

* please review [shellscript](shell/script.sh)

* please review [deployment](k8s/nginx.yaml)

* extras: proper explanation
