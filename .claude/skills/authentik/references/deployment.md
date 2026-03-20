# Authentik Kubernetes Deployment

## Helm Chart

```
Repo: https://charts.goauthentik.io
Chart: authentik/authentik
ArtifactHub: https://artifacthub.io/packages/helm/goauthentik/authentik
```

## Minimal Values

```yaml
authentik:
  secret_key: "<generate-with-openssl-rand-base64-32>"
  postgresql:
    password: "<secure-password>"

server:
  ingress:
    enabled: false  # use Traefik IngressRoute instead

postgresql:
  enabled: true
  auth:
    password: "<same-password-as-above>"

redis:
  enabled: true
```

**Generate secret key:** `openssl rand -base64 32`

## Production Values (Traefik + ArgoCD)

```yaml
authentik:
  secret_key: "<secret>"
  postgresql:
    password: "<password>"

server:
  replicas: 1
  metrics:
    enabled: true

worker:
  replicas: 1

postgresql:
  enabled: true
  auth:
    password: "<password>"
  primary:
    persistence:
      enabled: true
      size: 8Gi

redis:
  enabled: true
  master:
    persistence:
      enabled: true
      size: 2Gi

# Native blueprint ConfigMap mounting (no manual volumes needed)
# Only keys ending in .yaml are discovered
blueprints:
  configMaps:
    - authentik-blueprints-core
    - authentik-blueprints-apps
    - authentik-blueprints-proxy
```

## ArgoCD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: authentik
  namespace: argocd
spec:
  project: default
  sources:
    - repoURL: https://charts.goauthentik.io
      chart: authentik
      targetRevision: "2025.*"
      helm:
        valueFiles:
          - $values/apps/authentik/values.yaml
    - repoURL: git@github.com:<user>/<repo>.git
      targetRevision: HEAD
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: authentik
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

## Traefik IngressRoute

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: authentik
  namespace: authentik
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`auth.example.com`)
      kind: Rule
      services:
        - name: authentik-server
          port: 80
```

## Post-Install

1. Navigate to `https://auth.example.com/if/flow/initial-setup/`
2. Create admin account
3. Built-in PostgreSQL is for testing only; use CloudNativePG or Zalando operator for production

## Environment Variables

Set via `authentik.env` in Helm values or container env:

| Variable | Description |
|----------|-------------|
| `AUTHENTIK_SECRET_KEY` | Encryption key (required) |
| `AUTHENTIK_POSTGRESQL__HOST` | PostgreSQL host |
| `AUTHENTIK_POSTGRESQL__NAME` | Database name (default: `authentik`) |
| `AUTHENTIK_POSTGRESQL__USER` | Database user (default: `authentik`) |
| `AUTHENTIK_POSTGRESQL__PASSWORD` | Database password |
| `AUTHENTIK_REDIS__HOST` | Redis host |
| `AUTHENTIK_EMAIL__HOST` | SMTP host |
| `AUTHENTIK_EMAIL__PORT` | SMTP port |
| `AUTHENTIK_EMAIL__FROM` | From address |
| `AUTHENTIK_LOG_LEVEL` | Log level (debug/info/warning/error) |
