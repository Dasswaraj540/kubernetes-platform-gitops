# Terraform architecture

Module contents, inputs/outputs, remote-state design, tagging, and encryption touchpoints
are in [`terraform/README.md`](../terraform/README.md) and each module's own README. This
page is the operator view.

## Backend and credentials

No backend is committed — only `backend.tf.example`, so `terraform init` uses local state
until you wire remote state. No credentials, account IDs, or account-numbered ARNs are in
the repository. `terraform validate` runs offline; `terraform apply` is covered in
[deployment.md](deployment.md).

## Composition

`terraform/environments/<env>/main.tf` is identical across environments. It builds
`local.tags` and `local.name_prefix` / `local.cluster_name` from `var.environment`, then
wires:

```
vpc  ─────────────┐
kms  ──► ecr       │
kms  ──────────────┼──► eks ──► iam
vpc  ──────────────┘
ecr ──────────────────────────► iam   (CI push target ARN)
```

Per-environment differences are only in `variables.tf` defaults (CIDRs, node sizing,
`environment`) and the state `key`.

## State bootstrap (once, before any apply)

1. Create a KMS key aliased `alias/platform-tfstate`.
2. Create a versioned, private, SSE-KMS S3 bucket.
3. Create a DynamoDB table `platform-tfstate-locks` (partition key `LockID`, string).
4. In each `environments/<env>/`, `cp backend.tf.example backend.tf` and set the bucket name.

## Apply order

```bash
cd terraform/environments/dev
terraform init
terraform plan  -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

Then `staging`, then `prod`. `dev` first so problems surface cheaply.

## Outputs you will use

| Output | Feeds |
|---|---|
| `eks_cluster_name` | `aws eks update-kubeconfig --name <it>` |
| `ecr_repository_url` | chart `image.repository` (if moving off GHCR) |
| `platform_api_role_arn` | chart `serviceAccount.roleArn` |
| `oidc_provider_arn` | already consumed by the `iam` module |
| `gha_oidc_role_arn` | the `AWS_GHA_OIDC_ROLE_ARN` CI secret (if `gha_oidc_enabled`) |

## Cost note

An EKS cluster plus NAT gateway(s) and a node group is not free. Destroy environments you
are not using: `terraform destroy -var-file=terraform.tfvars`.
