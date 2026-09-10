# Observability

## Assumptions

- **kube-prometheus-stack** (Prometheus Operator, Alertmanager, Grafana,
  kube-state-metrics, node-exporter) is installed in a `monitoring` namespace.
- Prometheus is reachable in-cluster at `http://prometheus-operated.monitoring.svc:9090`
  (used by the Rollout `AnalysisTemplate`).
- Grafana can load dashboards from a sidecar or provisioning directory.

If the Prometheus Operator is **not** present, use
[`prometheus/scrape-config.example.yaml`](prometheus/scrape-config.example.yaml) instead of
the chart's `ServiceMonitor`.

## What lives where

| File | Role |
|---|---|
| `helm/platform-api/templates/servicemonitor.yaml` | The real scrape config (chart, gated `serviceMonitor.enabled`). Scrapes port `management` at `/actuator/prometheus`. |
| `helm/platform-api/templates/prometheusrule.yaml` | The real alert rules (chart, gated `prometheusRule.enabled`). Thresholds are chart values. |
| `prometheus/rules/platform-api-alerts.yaml` | A rendered, standalone copy of the chart's `PrometheusRule` (dev / Deployment variant) for reading without Helm. Edit the template, not this file. |
| `prometheus/scrape-config.example.yaml` | Static `scrape_configs` for a Prometheus without the Operator. |
| `grafana/dashboards/platform-api.json` | Dashboard model: request rate, latency percentiles, error ratio, JVM heap, container CPU/memory vs limit, pod restarts, saturation. Templated by `namespace`. |
| `opentelemetry/` | Collector config and agent wiring — see its README. |

## Signals

| Signal | Metric |
|---|---|
| Traffic | `rate(http_server_requests_seconds_count[5m])` |
| Latency | `histogram_quantile(q, sum by (le) (rate(http_server_requests_seconds_bucket[5m])))` |
| Errors | 5xx `http_server_requests_seconds_count` / total |
| Saturation | `tomcat_threads_busy_threads / tomcat_threads_config_max_threads`; `rate(container_cpu_cfs_throttled_periods_total[5m])` |
| CPU | `process_cpu_usage`, `container_cpu_usage_seconds_total` vs `kube_pod_container_resource_limits{resource="cpu"}` |
| Memory | `jvm_memory_used_bytes`, `container_memory_working_set_bytes` vs limit |
| Pod restarts | `kube_pod_container_status_restarts_total` (kube-state-metrics) |

## Alerts

`PlatformApiHighErrorRate`, `PlatformApiHighLatency`, `PlatformApiPodCrashLooping`,
`PlatformApiHighCpu`, `PlatformApiHighMemory`, `PlatformApiUnavailableReplicas`.

The unavailable-replicas rule has two forms: `kube_deployment_status_replicas_unavailable`
in `dev` (Deployment), and `rollout_info_replicas_unavailable` in `staging`/`prod` (Argo
Rollout). The chart template picks the right one from `argoRollouts.enabled`.

## Label conventions

Prometheus Operator adds `namespace`, `service`, and `pod` labels from the scraped Service
and Endpoints. Queries filter on `namespace` and `service` (`platform-api` stable,
`platform-api-canary` during a rollout). Alert and dashboard selectors use the same
convention.
