# Observability architecture

Signal catalogue, files, and label conventions are in
[`observability/README.md`](../observability/README.md). This page adds the SRE framing.

## The signals and where the decision lives

| Signal | Read on | Acted on by |
|---|---|---|
| Traffic (`rate(http_server_requests_seconds_count)`) | Grafana | capacity planning; HPA (indirectly, via CPU) |
| Latency (`histogram_quantile` on `_bucket`) | Grafana, alert `PlatformApiHighLatency` | SLO burn; rollout abort (canary success-rate proxy) |
| Errors (5xx ratio) | Grafana, alert `PlatformApiHighErrorRate` | paging; rollout `AnalysisTemplate` |
| Saturation | Grafana panel "Saturation" | scale-out decisions, thread-pool tuning |
| CPU / memory vs limit | Grafana, alerts `PlatformApiHighCpu` / `HighMemory` | HPA targets, limit tuning |
| Pod restarts | Grafana stat, alert `PlatformApiPodCrashLooping` | paging |
| Unavailable replicas | alert `PlatformApiUnavailableReplicas` | paging |

## Saturation, defined

`platform-api` runs on Tomcat. Saturation is measured as, in order of usefulness:

1. `tomcat_threads_busy_threads / tomcat_threads_config_max_threads` — request-handling
   headroom. Sustained > ~0.8 means requests are queueing.
2. `rate(container_cpu_cfs_throttled_periods_total[5m])` — CPU throttling. Non-zero means
   the CPU limit is the bottleneck.

Both are on the Grafana dashboard's "Saturation" panel.

## Toward SLOs (future work)

The alerts here are threshold alerts. A follow-up would define an availability SLO (e.g.
99.5% non-5xx over 30 days) and replace `PlatformApiHighErrorRate` with multi-window
multi-burn-rate rules against the error budget. The metric (`http_server_requests_seconds_*`)
already supports it.

## Scrape path

Chart `ServiceMonitor` → port `management` (8081) → `/actuator/prometheus`. No Operator?
Use `observability/prometheus/scrape-config.example.yaml`. Probes and metrics never touch
port 8080.
