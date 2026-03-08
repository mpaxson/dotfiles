# Datasource Configuration

## Prometheus (Built-in)

kube-prometheus-stack auto-configures Prometheus as default datasource. No additional setup needed.

Override defaults in Helm values if needed:
```yaml
grafana:
  additionalDataSources: []  # add extras here
  sidecar:
    datasources:
      defaultDatasourceEnabled: true  # auto-creates Prometheus DS
```

## Loki (Log Aggregation)

### Deployment

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm upgrade --install loki grafana/loki -n monitoring -f loki-values.yaml
```

Minimal single-binary values for small clusters:
```yaml
loki:
  auth_enabled: false
  commonConfig:
    replication_factor: 1
  storage:
    type: filesystem
  schemaConfig:
    configs:
      - from: "2024-01-01"
        store: tsdb
        object_store: filesystem
        schema: v13
        index:
          prefix: index_
          period: 24h
singleBinary:
  replicas: 1
  persistence:
    enabled: true
    storageClass: ceph-block
    size: 20Gi
```

### Log Collection Agent (Alloy/Promtail)

Deploy Grafana Alloy (successor to Promtail) to collect logs:
```bash
helm upgrade --install alloy grafana/alloy -n monitoring -f alloy-values.yaml
```

```yaml
# alloy-values.yaml
alloy:
  configMap:
    content: |
      discovery.kubernetes "pods" {
        role = "pod"
      }
      loki.source.kubernetes "pods" {
        targets = discovery.kubernetes.pods.targets
        forward_to = [loki.write.default.receiver]
      }
      loki.write "default" {
        endpoint {
          url = "http://loki:3100/loki/api/v1/push"
        }
      }
```

### Datasource ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: datasource-loki
  namespace: monitoring
  labels:
    grafana_datasource: "1"
data:
  loki.yaml: |
    apiVersion: 1
    datasources:
      - name: Loki
        type: loki
        url: http://loki:3100
        access: proxy
        isDefault: false
        jsonData:
          derivedFields:
            - name: TraceID
              matcherRegex: "traceID=(\\w+)"
              url: "$${__value.raw}"
              datasourceUid: tempo
```

## Tempo (Distributed Tracing)

### Deployment

```bash
helm upgrade --install tempo grafana/tempo -n monitoring -f tempo-values.yaml
```

```yaml
# tempo-values.yaml
tempo:
  storage:
    trace:
      backend: local
      local:
        path: /var/tempo/traces
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318
persistence:
  enabled: true
  storageClassName: ceph-block
  size: 10Gi
```

### Datasource ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: datasource-tempo
  namespace: monitoring
  labels:
    grafana_datasource: "1"
data:
  tempo.yaml: |
    apiVersion: 1
    datasources:
      - name: Tempo
        type: tempo
        url: http://tempo:3100
        access: proxy
        jsonData:
          tracesToMetrics:
            datasourceUid: prometheus
          tracesToLogs:
            datasourceUid: loki
            filterByTraceID: true
          serviceMap:
            datasourceUid: prometheus
          nodeGraph:
            enabled: true
```

## PostgreSQL (CNPG)

### Datasource ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: datasource-postgresql
  namespace: monitoring
  labels:
    grafana_datasource: "1"
data:
  postgresql.yaml: |
    apiVersion: 1
    datasources:
      - name: PostgreSQL
        type: postgres
        url: <cluster-name>-rw.<namespace>.svc:5432
        user: grafana_reader
        jsonData:
          database: <database>
          sslmode: require
          maxOpenConns: 5
          maxIdleConns: 2
        secureJsonData:
          password: "$GRAFANA_PG_PASSWORD"
```

### CNPG Read-Only User

Create a read-only user for Grafana: `CREATE ROLE grafana_reader WITH LOGIN PASSWORD '...'; GRANT CONNECT, USAGE ON SCHEMA public, SELECT ON ALL TABLES IN SCHEMA public TO grafana_reader;`

Alternative to ConfigMap sidecar: use `grafana.additionalDataSources` in kube-prometheus-stack Helm values.
