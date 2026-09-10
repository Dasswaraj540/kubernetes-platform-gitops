# Security

Defence in depth, expressed as configuration. Each area below has example files, not just
prose. No credentials, tokens, account IDs, or account-numbered ARNs appear anywhere in this
repository.

| Area | Where | What it enforces |
|---|---|---|
| Container | `docker/Dockerfile`, chart `securityContext` | multi-stage build, no build tools at runtime, non-root UID 10001, read-only root filesystem, all capabilities dropped, `seccomp: RuntimeDefault`, no secrets in the image |
| Pod / namespace | `k8s/namespaces/*`, chart, `kubernetes/hardening.md` | Pod Security Admission `restricted`, resource quotas + limit ranges, required requests/limits, probes |
| Network | `k8s/network` (default-deny), chart `networkpolicy.yaml`, `kubernetes/network-policy-model.md` | deny-all baseline, then explicit allows: ingress-controller → 8080, monitoring → 8081, DNS egress |
| Kubernetes RBAC | chart `role.yaml`/`rolebinding.yaml`, `k8s/rbac`, `rbac/model.md` | workload SA can read only its own ConfigMap; human access is a read-only `ClusterRole`; no `cluster-admin` bindings |
| AWS IAM | `terraform/modules/iam`, `iam/least-privilege.md`, `iam/platform-api-secrets-policy.json` | IRSA scoped to one ServiceAccount; Secrets Manager read scoped to one prefix; GitHub Actions via OIDC, no static keys |
| Secrets | chart `externalsecret.yaml`, `secrets/external-secrets-example.yaml`, `secrets/sops.md` | values pulled from AWS Secrets Manager into `platform-api-secrets`; SOPS documented for encrypted-in-Git manifests; no secret values committed |
| Image scanning | `images/trivy.yaml`, `scripts/image-scan.sh`, both pipelines | Trivy scan on every build; HIGH/CRITICAL fail the build unless explicitly, temporarily ignored |
| Dependency scanning | `dependencies/`, both pipelines | OWASP Dependency-Check; `failBuildOnCVSS=7`; suppressions are tracked and reviewed |
| Encryption | `terraform/modules/kms`, `eks`, `ecr` | KMS CMK for ECR at rest and EKS secrets envelope encryption; S3 state SSE-KMS |

## Principles

1. Least privilege everywhere — IAM, RBAC, NetworkPolicy, ECR pull, CI tokens.
2. No long-lived cloud credentials — IRSA for workloads, OIDC for CI.
3. Secrets never in Git — reference, never inline.
4. Fail the pipeline on unreviewed HIGH/CRITICAL findings; every suppression has an owner and
   an expiry.
5. Immutable, minimal, non-root images; the runtime filesystem is read-only.
