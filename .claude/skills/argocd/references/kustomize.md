# Kustomize

Kustomize builds Kubernetes manifests from bases + overlays without templating.
ArgoCD auto-detects kustomize when `kustomization.yaml` exists in path.

## Core Concepts

| Concept | API Version | Purpose |
|---------|-------------|---------|
| **Kustomization** | `kustomize.config.k8s.io/v1beta1` | Base or overlay - lists resources, patches, config |
| **Component** | `kustomize.config.k8s.io/v1alpha1` | Reusable mixin - shared across multiple kustomizations |

## Single Source of Truth Pattern

Store shared config in a Component. Each app references it and uses `replacements` to inject values.

### Shared Component

```
apps/
  _components/
    domain/
      kustomization.yaml    # kind: Component
      cluster-config.yaml   # ConfigMap with shared values
  myapp/
    kustomization.yaml      # references component, defines replacements
    ingressroute.yaml       # uses placeholder DOMAIN
```

```yaml
# _components/domain/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component
resources:
  - cluster-config.yaml
```

```yaml
# _components/domain/cluster-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-config
data:
  BASE_DOMAIN: home.kettle.sh
  argocd_host: argocd.home.kettle.sh
  auth_host: auth.home.kettle.sh
```

### Consuming Component with Replacements

```yaml
# apps/myapp/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ingressroute.yaml
components:
  - ../_components/domain
replacements:
  - source:
      kind: ConfigMap
      name: cluster-config
      fieldPath: data.myapp_host
    targets:
      - select:
          kind: IngressRoute
          name: myapp
        fieldPaths:
          - spec.routes.0.match
        options:
          delimiter: "`"    # Split on backtick
          index: 1          # Replace 2nd segment
```

```yaml
# apps/myapp/ingressroute.yaml - DOMAIN gets replaced
spec:
  routes:
    - match: Host(`DOMAIN`)   # DOMAIN replaced by replacements
```

**Key**: `delimiter` + `index` targets the value inside backticks without touching the `Host()` wrapper.

## Replacements Reference

Replacements are the modern alternative to deprecated `vars`. They copy values from source fields to target fields.

```yaml
replacements:
  - source:
      kind: <Kind>
      name: <name>
      fieldPath: <dot.path>        # e.g. data.mykey, spec.clusterIP
    targets:
      - select:
          kind: <Kind>             # target resource kind
          name: <name>             # target resource name (optional)
          namespace: <ns>          # optional
        reject:                    # exclude from selection (optional)
          - kind: ConfigMap
        fieldPaths:
          - spec.some.path
        options:
          delimiter: <string>      # split field value on delimiter
          index: <int>             # replace Nth segment (0-based)
          create: true             # create field if missing
```

## Base / Overlay Pattern

```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
```

```yaml
# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
patches:
  - path: patch-replicas.yaml
    target:
      kind: Deployment
      name: myapp
```

## Patches

### Strategic Merge Patch
```yaml
# patch-replicas.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 5
```

### JSON Patch (inline)
```yaml
patches:
  - target:
      kind: Deployment
      name: myapp
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 5
```

## Common Transformers

```yaml
# In kustomization.yaml
namespace: production         # Set namespace on all resources
namePrefix: prod-
nameSuffix: -v1
commonLabels:
  env: production
commonAnnotations:
  owner: platform-team
images:
  - name: myapp
    newName: registry.example.com/myapp
    newTag: v2.0.0
```

## ArgoCD Kustomize Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  source:
    repoURL: https://github.com/org/repo.git
    targetRevision: HEAD
    path: apps/myapp          # Path containing kustomization.yaml
    kustomize:                # Optional ArgoCD-level overrides
      images:
        - name: myapp
          newTag: v2.0.0
      namespace: production
      commonLabels:
        managed-by: argocd
      patches:                # Inline patches from ArgoCD
        - target:
            kind: Deployment
            name: myapp
          patch: |-
            - op: replace
              path: /spec/replicas
              value: 3
```

## Multi-Source: Helm Chart + Kustomize Sidecar

Deploy a Helm chart with additional kustomize-managed manifests (IngressRoutes, extra resources):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  sources:
    - repoURL: https://charts.example.com
      chart: myapp
      targetRevision: v1.0.0
      helm:
        valuesObject:
          key: value
    - repoURL: git@github.com:org/repo.git
      targetRevision: HEAD
      path: apps/myapp        # kustomization.yaml here
  destination:
    server: https://kubernetes.default.svc
    namespace: myapp
```

This keeps Helm values as the source of truth for the chart, and kustomize for supplementary resources (ingress, certs, CNPG clusters, etc.).

## Helm Inflation in Kustomize

Render Helm charts within kustomize (requires `--enable-helm` in ArgoCD):

```yaml
# argocd-cm ConfigMap
data:
  kustomize.buildOptions: --enable-helm
```

```yaml
# kustomization.yaml
helmCharts:
  - name: nginx
    repo: https://charts.bitnami.com/bitnami
    version: 15.1.0
    valuesFile: values.yaml
```

## CLI Overrides

```bash
argocd app set myapp --kustomize-image myapp=registry.example.com/myapp:v2
argocd app set myapp --kustomize-common-label env=staging
argocd app set myapp --nameprefix staging-
argocd app manifests myapp   # Show rendered output
```
