# Review — `k8s/nginx.yaml`

## Summary

The manifest defines an nginx Deployment and a Service. As written, neither
works: the Deployment's selector does not match its own pod template, and the
Service cannot route traffic to the pods even if they were running. Findings
below, in severity order.

## Issues

### 1. Selector does not match the pod template — Deployment is invalid

```yaml
selector:
  matchLabels:
    app: myNginx      # line 9
...
template:
  metadata:
    labels:
      app: myNgnx     # line 14 — missing the "i"
```

A Deployment's `selector` must match the labels on its pod template. Here they
differ by a typo (`myNginx` vs `myNgnx`), so the API server rejects the object
with `selector does not match template labels`.

This is the primary bug: nothing else in the file matters until it is fixed.

**Fix:** make both values identical.

### 2. Service has no selector — no endpoints

```yaml
kind: Service
spec:
  ports:
    - port: 8080
```

The Service spec defines ports but no `selector`. Without one, Kubernetes
creates no endpoints and the Service blackholes traffic. It will appear healthy
in `kubectl get svc` while never routing anything — a silent failure.

**Fix:** add a `selector` matching the pod labels.

### 3. Port chain is inconsistent

Three port values need to agree, and none of them do:

| Setting | Value | Should be |
|---|---|---|
| `containerPort` | 8000 | 80 |
| Service `port` | 8080 | (any, it is the Service's own port) |
| Service `targetPort` | absent → defaults to 8080 | 80 |

The `nginx` image serves on port **80** by default, not 8000. And because
`targetPort` is omitted, it defaults to the value of `port` (8080), so the
Service would forward to a port nothing is listening on.

**Fix:** set `containerPort: 80` and `targetPort: 80`.

### 4. Naming convention

`myNginx` is a valid label value, but camelCase is unconventional for
Kubernetes resources, where lowercase-with-hyphens is the norm. The typo in
issue 1 is exactly the class of error that inconsistent casing invites.

**Fix (optional):** rename to `nginx` or `my-nginx` throughout.

## Corrected manifest

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  selector:
    app: nginx
  ports:
    - port: 8080
      targetPort: 80
```

## Additional observations

Not bugs, but worth raising in a production context:

- **No image tag.** `image: nginx` resolves to `nginx:latest`, which makes
  deployments non-reproducible. Pin a version — `nginx:1.27-alpine`.
- **No resource requests or limits.** Without requests the scheduler cannot
  place the pod sensibly;
