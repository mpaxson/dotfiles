# Bundle Sources

A Bundle's `sources` is a list. All entries are concatenated into the final bundle in declaration order.

## 1. configMap

Reads PEM data from a ConfigMap in the trust namespace (default `cert-manager`).

```yaml
sources:
  - configMap:
      name: internal-root-ca       # OR selector (mutually exclusive)
      key: ca.crt                  # OR includeAllKeys: true (mutually exclusive)
```

Label-selector form (multi-source):
```yaml
  - configMap:
      selector:
        matchLabels:
          trust.cert-manager.io/source: "true"
      key: ca.crt
```

`includeAllKeys: true` pulls every data field — useful when key names are unknown at runtime.

## 2. secret

Same shape as `configMap`, reads from a Secret instead. Use for Secrets that cert-manager has populated, or for protected vendor roots.

```yaml
  - secret:
      name: my-ca-secret
      key: ca.crt
```

## 3. inLine

Inline PEM block — useful for one-off vendor roots without needing to manage a separate ConfigMap.

```yaml
  - inLine: |
      -----BEGIN CERTIFICATE-----
      MIIBkTCB+wIJAKHHCgVZylO6...
      -----END CERTIFICATE-----
```

## 4. useDefaultCAs

Includes the default Mozilla/Debian CA package shipped with the controller. Requires `defaultPackage.enabled=true` in Helm values (default).

```yaml
  - useDefaultCAs: true
```

The package version is exposed at `bundle.status.defaultCAVersion`.

## Combining Sources

Sources are concatenated in order. Typical pattern: public roots + internal CA(s) + vendor roots:

```yaml
sources:
  - useDefaultCAs: true
  - configMap:
      name: internal-root-ca
      key: ca.crt
  - secret:
      name: vendor-partner-root
      key: ca.crt
  - inLine: |
      -----BEGIN CERTIFICATE-----
      ...legacy partner root...
      -----END CERTIFICATE-----
```

## Constraints

- For `configMap` / `secret`: `name` and `selector` are **mutually exclusive**
- `key` and `includeAllKeys: true` are **mutually exclusive**
- All non-`useDefaultCAs` / non-`inLine` sources resolve only within the **trust namespace**
- All source data must be valid PEM — DER input fails with `SourceBuilderError`
- Avoid sourcing intermediate certs; bundles should contain **roots only** (see `cert-manager-integration.md`)
