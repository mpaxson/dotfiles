# trust-manager Helm Installation

## Prerequisites

- Kubernetes cluster
- **cert-manager installed first** — trust-manager depends on cert-manager to provision its webhook serving certificate (unless using `app.webhook.tls.helmCert.enabled=true`)
- Helm 3.8+ (OCI registry support)

## Standard Install

```bash
# 1. Install cert-manager
helm upgrade cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --install \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  --wait

# 2. Install trust-manager into the same namespace
helm upgrade trust-manager oci://quay.io/jetstack/charts/trust-manager \
  --install \
  --namespace cert-manager \
  --wait
```

The chart is also mirrored on the legacy Helm repo: `https://charts.jetstack.io`.

## Trust Namespace

By default the controller only reads sources from the namespace it lives in (`cert-manager`). Override:

```bash
--set app.trust.namespace=trust-sources
```

Best practice: dedicate a separate namespace (e.g. `trust-sources`) so fewer actors have RBAC to mutate trust inputs. The controller can still run in `cert-manager`.

## values.yaml — Production Example

```yaml
replicaCount: 2

resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    memory: 128Mi

priorityClassName: system-cluster-critical

app:
  trust:
    namespace: trust-sources
  logLevel: 1
  metrics:
    port: 9402
  readinessProbe:
    port: 6060
    path: /readyz

  # Enable Secret targets (off by default)
  secretTargets:
    enabled: true
    # Either grant access to all Secrets in target namespaces:
    authorizedSecretsAll: true
    # Or restrict to a named list:
    # authorizedSecrets:
    #   - my-trust-bundle

  # Filter expired roots from default CAs (off by default in older versions)
  filterExpiredCertificates:
    enabled: true

defaultPackage:
  enabled: true   # required for `useDefaultCAs: true` sources

defaultPackageImage:
  repository: quay.io/jetstack/trust-pkg-debian-bookworm
  # tag: <pinned>  # pin for reproducibility
```

Apply with:
```bash
helm upgrade trust-manager oci://quay.io/jetstack/charts/trust-manager \
  --install --namespace cert-manager -f values.yaml --wait
```

## Webhook Certificate Options

trust-manager runs an admission webhook and needs a serving cert. Two options:

1. **cert-manager-issued (default, recommended):** chart creates an `Issuer` + `Certificate` automatically. Requires cert-manager to be installed and ready.
2. **Helm-generated cert:** for resource-constrained or pre-cert-manager bootstraps:
   ```bash
   --set app.webhook.tls.helmCert.enabled=true
   ```
   Not recommended for production (rotation requires `helm upgrade`).

## approver-policy Integration

If the cluster runs cert-manager-approver-policy, the chart's webhook Certificate will be blocked unless trust-manager is auto-approved:

```bash
--set app.webhook.tls.approverPolicy.enabled=true \
--set app.webhook.tls.approverPolicy.certManagerNamespace=cert-manager
```

This installs a `CertificateRequestPolicy` granting approval for trust-manager's own webhook cert.

## Default CA Package

`useDefaultCAs: true` only works when the controller is started with a default package mounted. The chart handles this when `defaultPackage.enabled=true` (default). The package is a sidecar/init image:

| Image | Base |
|-------|------|
| `quay.io/jetstack/trust-pkg-debian-bookworm` | Debian Bookworm (current) |
| `quay.io/jetstack/cert-manager-package-debian` | Debian Bullseye (legacy ≤ v0.15) |

To pin or air-gap, mirror the image and set `defaultPackageImage.repository` + `tag`.

## Uninstall

```bash
helm uninstall trust-manager -n cert-manager
kubectl delete crd bundles.trust.cert-manager.io
```

CRD removal also deletes all Bundles and the ConfigMaps/Secrets they synced.

## Verification After Install

```bash
kubectl -n cert-manager rollout status deploy/trust-manager
kubectl get crd bundles.trust.cert-manager.io
kubectl -n cert-manager logs deploy/trust-manager | head -20
```

Apply the minimal Bundle from `SKILL.md` to confirm end-to-end sync works.
