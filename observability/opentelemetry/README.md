# OpenTelemetry

`platform-api` carries **no** OpenTelemetry code. Tracing is added at runtime with the
OpenTelemetry Java agent, and it is off by default.

## Enabling it

Set `otel.enabled: true` in an environment's `argocd/envs/<env>/values.yaml`. The chart then
adds these container environment variables (see `helm/platform-api/templates/_helpers.tpl`,
`platform-api.podEnv`):

| Variable | Value |
|---|---|
| `JAVA_TOOL_OPTIONS` | `... -javaagent:/otel/opentelemetry-javaagent.jar` |
| `OTEL_SERVICE_NAME` | `platform-api` |
| `OTEL_RESOURCE_ATTRIBUTES` | `service.namespace=platform,deployment.environment=<env>` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `otel.endpoint` value (default `http://otel-collector.observability.svc:4317`) |
| `OTEL_TRACES_SAMPLER` | `parentbased_traceidratio` |
| `OTEL_TRACES_SAMPLER_ARG` | `otel.samplerArg` value (default `0.1`) |
| `OTEL_METRICS_EXPORTER` / `OTEL_LOGS_EXPORTER` | `none` — metrics stay on Micrometer/Prometheus, logs stay on stdout |

The agent jar itself must be present at `/otel/opentelemetry-javaagent.jar`. Add it either
by baking a stage into `docker/Dockerfile` that copies it from
`ghcr.io/open-telemetry/opentelemetry-java-instrumentation/opentelemetry-agent`, or with an
init container that downloads it into a shared `emptyDir`. This repo does not enable it, so
the jar is not bundled.

## Collector

`collector.yaml` is a gateway-style Collector `Deployment` for the `observability` namespace:
OTLP in (gRPC 4317 / HTTP 4318) → `memory_limiter` → `resourcedetection` → `batch` → OTLP
out to Tempo, plus a `debug` exporter. It is a reference; it is not wired into any Argo CD
Application.

## Log correlation

`platform-api` logs are ECS JSON on stdout (`logging.structured.format.console: ecs`). With
the agent active, `trace_id` and `span_id` are injected into the MDC and appear in every log
line, so a log line links to its trace in the backend.
