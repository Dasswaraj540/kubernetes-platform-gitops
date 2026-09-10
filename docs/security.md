# Security architecture

The control-by-control detail and example files are in
[`security/README.md`](../security/README.md). This page frames it.

## What is being defended

| Asset | Main threats | Primary controls |
|---|---|---|
| The running container | remote code execution, privilege escalation, container escape | non-root, read-only rootfs, drop all caps, `seccomp: RuntimeDefault`, PSA `restricted`, no shell in the runtime image |
| The image supply chain | vulnerable base/deps, tampered image, secret baked in | multi-stage build, Trivy scan (fail on HIGH/CRITICAL), OWASP Dependency-Check (fail CVSS ≥ 7), immutable SHA tags, `.dockerignore` |
| Cluster blast radius | one compromised pod reaching others or the API | namespaced RBAC (own ConfigMap only), default-deny NetworkPolicy + minimal allows, ResourceQuota/LimitRange |
| Cloud blast radius | stolen pod identity, over-broad CI credentials | IRSA scoped to one ServiceAccount + one Secrets Manager prefix; CI via GitHub OIDC, no static keys |
| Secrets | plaintext in Git, in image, or in logs | External Secrets Operator → Secrets Manager; SOPS alternative; nothing secret committed |
| Data at rest | unencrypted images / etcd secrets / state | KMS CMK for ECR and EKS secrets; S3 state SSE-KMS |

## Trust boundaries

1. **Internet → Ingress** — TLS terminates at ingress-nginx (chart `ingress.tls`, gated);
   only port 8080 is reachable, and only from the ingress-controller namespace.
2. **Pod → Kubernetes API** — the ServiceAccount can read one ConfigMap. Nothing else.
3. **Pod → AWS** — the IRSA role reads one Secrets Manager prefix. Nothing else.
4. **CI → registry / Git** — scoped tokens; the GitOps commit is to `main` only.
5. **CI → AWS** — only if `gha_oidc_enabled`, and then only ECR push on one repo ARN.

## Gaps and candidate additions

- No image signing / admission verification yet (see the README's future work).
- No runtime security (Falco/Tetragon).
- Ingress and mesh mTLS not configured; east-west traffic relies on NetworkPolicy only.
