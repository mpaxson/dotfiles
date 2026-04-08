# trust-manager Troubleshooting

## First Commands

```bash
kubectl get bundle
kubectl describe bundle <name>
kubectl -n cert-manager logs deploy/trust-manager --tail=100
kubectl get crd bundles.trust.cert-manager.io -o jsonpath='{.spec.versions[*].name}'
```

Healthy status:
```yaml
status:
  conditions:
    - type: Synced
      status: "True"
      reason: Synced
```

## `Synced=False` reason `SourceNotFound`

Source ConfigMap/Secret missing, in wrong namespace, or wrong key.

```bash
# Find the trust namespace
kubectl -n cert-manager get deploy trust-manager -o yaml | grep -A1 trust-namespace

# Verify object exists
kubectl -n cert-manager get configmap <source-name> -o yaml
```

Key names are case-sensitive. Re-check label selectors if using `selector:` form.

## `SourceBuilderError` / non-PEM data

Source data is not valid PEM. Decode and validate:
```bash
kubectl -n cert-manager get configmap <name> -o jsonpath='{.data.ca\.crt}' \
  | openssl x509 -noout -text
```

If openssl errors, re-export: `openssl x509 -in original.crt -outform PEM -out ca.pem`.

## Target ConfigMap missing in expected namespaces

`namespaceSelector` does not match. Selectors apply to **namespace labels**, not workload labels.

```bash
kubectl get ns my-app --show-labels
kubectl get bundle <name> -o jsonpath='{.spec.target.namespaceSelector}'
kubectl label ns my-app trust=enabled
```

## `secret target requires --secret-targets-enabled`

Bundle uses `target.secret`, but the controller was started without secret-target support.

```bash
helm upgrade trust-manager oci://quay.io/jetstack/charts/trust-manager \
  --install -n cert-manager \
  --set secretTargets.enabled=true \
  --set secretTargets.authorizedSecretsAll=true \
  --reuse-values --wait
```

For least-privilege RBAC, list specific Secret names instead via `secretTargets.authorizedSecrets`.

## Webhook fails on install — `failed calling webhook`

cert-manager is not installed/ready, so trust-manager's webhook serving cert was never issued.

```bash
kubectl -n cert-manager get pods
kubectl -n cert-manager get certificate trust-manager
kubectl -n cert-manager describe certificate trust-manager
```

If approver-policy is in the cluster, ensure the chart was installed with:
```bash
--set app.webhook.tls.approverPolicy.enabled=true \
--set app.webhook.tls.approverPolicy.certManagerNamespace=cert-manager
```

## `useDefaultCAs: true` produces empty bundle

Default package was disabled, or its image is missing.

```bash
helm get values trust-manager -n cert-manager | grep -A3 defaultPackage
kubectl -n cert-manager get pod -l app.kubernetes.io/name=trust-manager -o yaml \
  | grep -A5 initContainers
```

Re-enable:
```bash
helm upgrade trust-manager oci://quay.io/jetstack/charts/trust-manager \
  --install -n cert-manager --set defaultPackage.enabled=true --reuse-values --wait
```

## JKS/PKCS12 not generated

`additionalFormats` only takes effect when the **target object** is created. After enabling, delete the target once:
```bash
kubectl -n my-app delete configmap <bundle-name>
```

Validate produced JKS:
```bash
kubectl get cm <bundle-name> -n my-app -o jsonpath='{.data.truststore\.jks}' \
  | keytool -list -storetype JKS -storepass changeit
```

## Bundle reconciles but pods still see old roots

ConfigMap mounts using `subPath` do **not** auto-update — kubelet only updates directory mounts.

```bash
kubectl -n my-app rollout restart deploy/<name>
```

For zero-restart updates, mount the ConfigMap **without** `subPath`. See `bundle-targets.md`.

## Increase Controller Verbosity

```bash
helm upgrade trust-manager oci://quay.io/jetstack/charts/trust-manager \
  --install -n cert-manager --set app.logLevel=5 --reuse-values --wait
kubectl -n cert-manager logs deploy/trust-manager -f
```

Reset `app.logLevel=1` after debugging.
