# cert-manager Integration

trust-manager and cert-manager are independent but designed to work together. cert-manager **issues** certificates; trust-manager **distributes** the trust roots needed to validate them.

## The `ca.crt` vs `tls.crt` Trap

A cert-manager Certificate produces a Secret with these keys:

| Key | Contents | Use as trust source? |
|-----|----------|----------------------|
| `tls.crt` | Leaf cert + intermediate chain (PEM) | **Never** — contains intermediates and the leaf, both rotate |
| `tls.key` | Private key | Never (not a cert) |
| `ca.crt` | The issuing CA's root cert, **best-effort** | Only when populated and only the **root** |

**`ca.crt` is best-effort.** It is only populated when the issuer can determine its own root:

- `CA` issuer: populated when the source Secret contains `ca.crt` alongside the signing key
- `SelfSigned`: not populated (the cert is its own root, use `tls.crt` directly is wrong too — use the leaf)
- `Vault`: populated if the PKI mount returns a chain
- `ACME` (Let's Encrypt): rarely useful — public roots, just use `useDefaultCAs: true`

**Safer pattern:** copy the root out of band into a dedicated ConfigMap and source that:

```bash
kubectl -n cert-manager get secret root-ca-secret -o jsonpath='{.data.ca\.crt}' \
  | base64 -d > root-ca.pem
kubectl -n cert-manager create configmap internal-root-ca \
  --from-file=ca.crt=root-ca.pem
```

Then in the Bundle:
```yaml
sources:
  - configMap:
      name: internal-root-ca
      key: ca.crt
```

## Bootstrap Pattern: SelfSigned → CA Issuer → Bundle

This is the canonical private PKI bootstrap that pairs with the cert-manager skill:

```yaml
# 1. SelfSigned bootstrap issuer
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-bootstrap
spec:
  selfSigned: {}
---
# 2. Self-signed root CA Certificate
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: root-ca
  namespace: cert-manager
spec:
  isCA: true
  commonName: org-root-ca
  duration: 87600h     # 10 years
  secretName: root-ca-secret
  privateKey:
    algorithm: ECDSA
    size: 256
  issuerRef:
    name: selfsigned-bootstrap
    kind: ClusterIssuer
---
# 3. CA ClusterIssuer using the root
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: org-ca
spec:
  ca:
    secretName: root-ca-secret
---
# 4. trust-manager Bundle distributing the root
apiVersion: trust.cert-manager.io/v1alpha1
kind: Bundle
metadata:
  name: org-trust
spec:
  sources:
    - secret:
        name: root-ca-secret
        key: ca.crt          # populated by the CA issuer chain
  target:
    configMap:
      key: ca-bundle.crt
    namespaceSelector:
      matchLabels:
        trust: enabled
```

Now any leaf cert issued by `org-ca` is verifiable by any pod that mounts the `org-trust` ConfigMap.

## Root Rotation (Zero-Downtime)

Switching root CAs without breaking running workloads requires a **transition window** where both roots are trusted.

1. **Add the new root** alongside the old one in the Bundle:
   ```yaml
   sources:
     - secret: { name: root-ca-secret-old, key: ca.crt }
     - secret: { name: root-ca-secret-new, key: ca.crt }
   ```
2. **Wait** for trust-manager to sync. All consumers now trust both.
3. **Switch the issuer** to sign with the new root (update `ca:` ClusterIssuer's `secretName`).
4. **Renew leaf certs** so they chain to the new root.
5. **Remove the old root source** from the Bundle once all leaves have rotated.

Skipping the transition window will break TLS for any workload still presenting an old-root-signed cert.

## Anti-Patterns

- **Sourcing `tls.crt`** from a leaf certificate Secret — pulls intermediates that rotate.
- **Bundling intermediate certs** as if they were roots — they have shorter lifetimes and defeat trust pinning.
- **Single-source bundle pointing to `webhook-ca` Secret** — cert-manager rotates these; consumers will silently break.
- **Using `useDefaultCAs: true` for private PKI** — defaults are public Mozilla roots, will not validate internal certs.

## Co-installing the Charts

Both charts go into the **same namespace** by default (`cert-manager`). trust-manager's webhook Certificate is issued by an Issuer the chart creates, which depends on cert-manager already being healthy. Install order matters:

```bash
helm upgrade cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --install -n cert-manager --create-namespace --set crds.enabled=true --wait

helm upgrade trust-manager oci://quay.io/jetstack/charts/trust-manager \
  --install -n cert-manager --wait
```

If cert-manager-approver-policy is in the cluster, also pass:
```bash
--set app.webhook.tls.approverPolicy.enabled=true \
--set app.webhook.tls.approverPolicy.certManagerNamespace=cert-manager
```

See `helm-installation.md` for full values.
