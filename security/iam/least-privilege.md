# AWS IAM — least privilege

No IAM user, access key, or long-lived credential is used anywhere. Two identities exist,
both federated.

## Workload → AWS: IRSA

`terraform/modules/iam` creates a role whose trust policy allows
`sts:AssumeRoleWithWebIdentity` **only** from the cluster's OIDC provider, and **only** for:

```
sub = system:serviceaccount:platform-<env>:platform-api
aud = sts.amazonaws.com
```

Its inline policy (`platform-api-secrets-policy.json` is the rendered shape) allows reading
just the Secrets Manager entries under `platform/<env>/platform-api*`. Nothing else — no S3,
no broad `secretsmanager:*`, no `*` resource except the unavoidable `ListSecrets`.

The role ARN is surfaced as the Terraform output `platform_api_role_arn` and set on the
chart value `serviceAccount.roleArn`, which renders the
`eks.amazonaws.com/role-arn` annotation on the ServiceAccount.

## CI → AWS: GitHub OIDC (optional, off by default)

When `gha_oidc_enabled = true`, a second role trusts `token.actions.githubusercontent.com`
for exactly `repo:OWNER/kubernetes-platform-gitops:ref:refs/heads/main`, with a policy that
allows `ecr:GetAuthorizationToken` (on `*`, as AWS requires) and the push actions on the
single `platform-api` repository ARN. Its ARN is what the `AWS_GHA_OIDC_ROLE_ARN` GitHub
secret would hold. The committed pipelines do not use it — they publish to GHCR.

## Rules

- Scope every statement to a resource ARN. `Resource: "*"` only where the action genuinely
  has no resource (`ecr:GetAuthorizationToken`, `secretsmanager:ListSecrets`).
- Trust policies name one `sub`. No wildcard subjects, no `*` audiences.
- Managed policies limited to the AWS-required EKS set (`AmazonEKSClusterPolicy`,
  `AmazonEKS_CNI_Policy`, `AmazonEKSWorkerNodePolicy`, `AmazonEC2ContainerRegistryReadOnly`,
  `AmazonSSMManagedInstanceCore`).
- No `iam:PassRole` grants outside the EKS/node roles Terraform manages.
