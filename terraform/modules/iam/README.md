# Module: `iam`

Application and CI identity for one environment.

## `platform-api` IRSA role

An IAM role the `platform-api` pod assumes through the cluster OIDC provider. The trust
policy is scoped to exactly one subject:

```
system:serviceaccount:<namespace>:platform-api
```

with `aud = sts.amazonaws.com`. Its inline policy allows reading only the Secrets Manager
entries under `secrets_manager_prefix` (e.g. `platform/dev/platform-api/*`).
`platform_api_role_arn` is the value for the chart's
`serviceAccount.roleArn` (rendered as the `eks.amazonaws.com/role-arn` annotation).

## GitHub Actions OIDC role (optional)

When `gha_oidc_enabled = true`, creates a role that `token.actions.githubusercontent.com`
can assume from `repo:<gha_repository>:ref:refs/heads/<gha_branch>`, with a policy that
allows pushing to the one ECR repository (`ecr_repository_arn`). Its ARN
(`gha_oidc_role_arn`) is what the `AWS_GHA_OIDC_ROLE_ARN` CI secret would hold. Disabled by
default — the committed pipelines publish to GHCR.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name_prefix` | string | — | e.g. `platform-dev` |
| `oidc_provider_arn` | string | — | `module.eks.oidc_provider_arn` |
| `oidc_provider_url` | string | — | `module.eks.oidc_provider_url` |
| `namespace` | string | — | e.g. `platform-dev` |
| `service_account_name` | string | `platform-api` | |
| `secrets_manager_prefix` | string | — | e.g. `platform/dev/platform-api` |
| `gha_oidc_enabled` | bool | `false` | |
| `gha_repository` | string | `""` | `OWNER/kubernetes-platform-gitops` |
| `gha_branch` | string | `main` | |
| `ecr_repository_arn` | string | `""` | from `module.ecr.repository_arn` |
| `tags` | map(string) | `{}` | |

## Outputs

`platform_api_role_arn`, `platform_api_role_name`, `gha_oidc_role_arn`.
