# Progressive delivery

Mechanics and operator commands are in [`rollouts/README.md`](../rollouts/README.md). This
page covers the analysis design and how to tune it.

## Why background analysis, starting at step 2

The chart wires the `AnalysisTemplate` as `strategy.canary.analysis` with `startingStep: 2`,
not as an inline step. So:

- the canary takes its first traffic (step 0, `setWeight: 20`) and settles through the first
  pause before any judgement is made — no analysis against zero samples;
- from step 2 on, one `AnalysisRun` runs continuously in the background across the remaining
  steps, rather than a fresh run per step.

## The query

```
sum(rate(http_server_requests_seconds_count{namespace="<ns>",service="platform-api-canary",status!~"5.."}[2m]))
/
sum(rate(http_server_requests_seconds_count{namespace="<ns>",service="platform-api-canary"}[2m]))
```

`service="platform-api-canary"` isolates the canary — the Prometheus Operator sets the
`service` label from the scraped Service, and the canary Service only selects canary pods
once the Rollout injects its pod-hash. `status!~"5.."` counts every non-5xx as success
(4xx is a client problem, not a canary regression).

## Tuning (`argoRollouts.analysis` in values)

| Key | Default | Raise it when | Lower it when |
|---|---|---|---|
| `successRateThreshold` | `"0.95"` | the service has a strict SLO | the service is chatty with 5xx-ish health probes (it should not be — probes are on 8081) |
| `intervalSeconds` | `60` | traffic is low and 1-minute windows are noisy | you want faster abort |
| `count` | `3` | you want more confirmations before promote | — |
| `failureLimit` | `1` | transient blips cause false aborts | you want zero tolerance |

`prod` also overrides `argoRollouts.steps` with smaller weights (10/25/50/75) and longer
pauses.

## Rollback

A failed `AnalysisRun` aborts the Rollout; the stable ReplicaSet keeps all traffic and the
canary scales to zero. Nothing is deleted, so `kubectl argo rollouts retry` or a fixed image
tag via GitOps resumes. Manual abort/undo commands are in `rollouts/README.md`.
