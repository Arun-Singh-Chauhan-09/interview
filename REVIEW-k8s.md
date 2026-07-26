# Review — k8s/nginx.yaml

An nginx Deployment + Service. As written neither works: the Deployment's selector
doesn't match its pod template, and the Service has no selector so it routes nowhere.

## Bugs

1. **Selector ≠ template labels — Deployment is invalid.** `matchLabels.app: myNginx`
   vs template label `app: myNgnx` (missing `i`). The API server rejects it with
   *selector does not match template labels*. Primary bug — fix first. Make both identical.

2. **Service has no selector — no endpoints.** Ports defined, but no `selector`, so
   Kubernetes creates no endpoints and traffic blackholes. Looks healthy in
   `kubectl get svc` while routing nothing. Add a selector matching the pod labels.

3. **Port chain inconsistent.** nginx serves on **80**, but `containerPort: 8000`;
   and `targetPort` is omitted so it defaults to `port` (8080) → forwards to a dead
   port. Set `containerPort: 80` and `targetPort: 80`.

4. **Naming (optional).** camelCase `myNginx` is unconventional; k8s uses
   lowercase-with-hyphens. That casing is exactly what invited the typo in #1.
   Rename to `nginx` / `my-nginx`.

## Corrected

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  labels: { app: nginx }
spec:
  replicas: 2
  selector:
    matchLabels: { app: nginx }
  template:
    metadata:
      labels: { app: nginx }
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine   # pinned, not :latest
          ports:
            - containerPort: 80
          resources:
            requests: { cpu: 50m, memory: 64Mi }
            limits:   { cpu: 200m, memory: 128Mi }
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels: { app: nginx }
spec:
  selector: { app: nginx }
  ports:
    - port: 8080
      targetPort: 80
```

*Also (not bugs): pinned the image tag (`:latest` is non-reproducible) and added
resource requests/limits so the scheduler can place the pod.*
