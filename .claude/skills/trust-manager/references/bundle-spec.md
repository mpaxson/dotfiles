# Bundle CRD Overview

`apiVersion: trust.cert-manager.io/v1alpha1` — Bundle is **cluster-scoped**.

```yaml
apiVersion: trust.cert-manager.io/v1alpha1
kind: Bundle
metadata:
  name: example
spec:
  sources: [...]   # required, ordered list, concatenated in order
  target: {...}    # required, single destination
status:
  conditions: [...]
  defaultCAVersion: <string>   # only when useDefaultCAs is used
```

For source field details (configMap, secret, inLine, useDefaultCAs, selectors), see `bundle-sources.md`.
For target field details (configMap, secret, namespaceSelector, additionalFormats, pod mounting), see `bundle-targets.md`.

## Status Conditions

```bash
kubectl get bundle <name> -o jsonpath='{.status.conditions}'
```

Healthy:
```yaml
- type: Synced
  status: "True"
  reason: Synced
  message: "Successfully synced Bundle to all namespaces"
  observedGeneration: <gen>
```

Common failure reasons: `SourceNotFound`, `SourceBuilderError`, `TargetUpdateFailed`. See `troubleshooting.md`.

## Full Reference Example

```yaml
apiVersion: trust.cert-manager.io/v1alpha1
kind: Bundle
metadata:
  name: org-full-trust
spec:
  sources:
    - useDefaultCAs: true
    - configMap:
        name: internal-root-ca
        key: ca.crt
    - secret:
        name: vendor-root
        key: ca.crt
    - inLine: |
        -----BEGIN CERTIFICATE-----
        ...legacy partner root...
        -----END CERTIFICATE-----
  target:
    configMap:
      key: ca-bundle.crt
      metadata:
        labels:
          app.kubernetes.io/managed-by: trust-manager
    namespaceSelector:
      matchLabels:
        trust: enabled
    additionalFormats:
      jks:
        key: truststore.jks
        password: changeit
      pkcs12:
        key: truststore.p12
        profile: Modern2023
```
