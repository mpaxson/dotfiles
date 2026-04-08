# Bundle Targets

A Bundle has exactly one `target`. The destination's name always equals `bundle.metadata.name`.

## configMap target

```yaml
target:
  configMap:
    key: ca-bundle.crt
    metadata:
      labels:
        managed-by: trust-manager
      annotations:
        description: "org trust bundle"
```

## secret target

Requires `secretTargets.enabled=true` in Helm values + RBAC (`authorizedSecretsAll` or `authorizedSecrets`). See `helm-installation.md`.

```yaml
target:
  secret:
    key: ca-bundle.crt
```

## namespaceSelector

Restricts which namespaces receive the target. **Without this, the bundle syncs to every namespace.**

```yaml
target:
  configMap:
    key: ca-bundle.crt
  namespaceSelector:
    matchLabels:
      trust: enabled
```

To make a namespace eligible:
```bash
kubectl label ns my-app trust=enabled
```

trust-manager reconciles within seconds.

## additionalFormats

Generate JKS and/or PKCS12 binary keystores in the same target object alongside the PEM key.

```yaml
target:
  configMap:
    key: ca-bundle.crt
  additionalFormats:
    jks:
      key: truststore.jks
      password: changeit              # default
    pkcs12:
      key: truststore.p12
      password: ""                    # default: passwordless
      profile: Modern2023             # LegacyRC2 | LegacyDES | Modern2023
```

JKS is deprecated upstream but widely consumed by Java workloads. PKCS12 is preferred for new deployments.

`additionalFormats` only takes effect on target object **creation**. After enabling on an existing Bundle, delete the target object once so the controller rebuilds it:
```bash
kubectl -n my-app delete configmap <bundle-name>
```

## Mounting in Pods

```yaml
volumes:
  - name: trust
    configMap:
      name: org-full-trust
volumeMounts:
  - name: trust
    mountPath: /etc/ssl/certs/ca-bundle.crt
    subPath: ca-bundle.crt
    readOnly: true
```

**Warning:** `subPath` mounts do **not** auto-update when the source ConfigMap changes. Use a directory mount (no `subPath`) for live rotation, or roll the deployment after Bundle changes:
```bash
kubectl -n my-app rollout restart deploy/<name>
```

## Java Keystore Consumption

```yaml
env:
  - name: JAVA_TOOL_OPTIONS
    value: "-Djavax.net.ssl.trustStore=/etc/trust/truststore.jks -Djavax.net.ssl.trustStorePassword=changeit"
volumeMounts:
  - name: trust
    mountPath: /etc/trust
```

For OpenJDK 11+, prefer PKCS12 (`-Djavax.net.ssl.trustStoreType=PKCS12`) — JKS support is being removed upstream.

## System CA Replacement

To **replace** the system CA store inside a container (e.g. for `curl`, Go HTTP clients), mount over `/etc/ssl/certs/ca-certificates.crt`:

```yaml
volumeMounts:
  - name: trust
    mountPath: /etc/ssl/certs/ca-certificates.crt
    subPath: ca-bundle.crt
    readOnly: true
```

This works for Debian/Ubuntu/Alpine bases. RHEL/UBI uses `/etc/pki/ca-trust/source/anchors/`.
