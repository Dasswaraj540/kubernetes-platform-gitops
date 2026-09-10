# Deployment

The runbook for provisioning the AWS substrate and bringing the platform up in an account.

## 0. Prerequisites

- An AWS account and a role you can assume locally.
- Tools: `terraform` ≥ 1.6, `kubectl` ≥ 1.28, `helm` ≥ 3.14, `aws` CLI v2,
  `argocd` CLI, `kubectl-argo-rollouts`, `yq`.
- A GitHub account/org to replace `OWNER`.

## 1. Replace placeholders

- `OWNER` → your GitHub owner, everywhere (`git grep -n OWNER`).
- `example.com` ingress hosts in `argocd/envs/*/values.yaml` → real DNS you control.
- Region (`eu-west-1`) in `terraform/environments/*` if not eu-west-1.

## 2. Terraform state bootstrap

Follow [terraform.md](terraform.md) → "State bootstrap": KMS alias `platform-tfstate`, an
SSE-KMS S3 bucket, a DynamoDB lock table. Then `cp backend.tf.example backend.tf` per env
and set the bucket.

## 3. Provision infrastructure (dev first)

```bash
cd terraform/environments/dev
terraform init && terraform apply -var-file=terraform.tfvars
```

Repeat for `staging`, `prod`. Note the outputs: `eks_cluster_name`, `ecr_repository_url`,
`platform_api_role_arn`.

## 4. Cluster access and add-ons

```bash
aws eks update-kubeconfig --name platform-dev-eks --region <region>
```

Install, per cluster (Helm; not managed by this repo):

- **ingress-nginx** — `ingressClassName: nginx` must exist.
- **Argo CD** — into namespace `argocd`.
- **Argo Rollouts** — controller + `kubectl-argo-rollouts`.
- **kube-prometheus-stack** — into namespace `monitoring`; expect
  `prometheus-operated.monitoring.svc:9090`.
- **External Secrets Operator** — into namespace `external-secrets` (only if you set
  `externalSecrets.enabled`).

## 5. Choose the registry

- Staying on GHCR: nothing to do; `image.repository` already points there.
- Moving to ECR: set `image.repository` to `ecr_repository_url`, set
  `gha_oidc_enabled = true` in `terraform/environments/*`, re-apply `iam`, set the
  `AWS_GHA_OIDC_ROLE_ARN` GitHub secret and `ENABLE_ECR_PUBLISH=true` repo variable.

## 6. Wire IRSA

Set `serviceAccount.roleArn` in each `argocd/envs/<env>/values.yaml` to that environment's
`platform_api_role_arn`.

## 7. Bootstrap namespaces and Argo CD objects

```bash
kubectl apply -f k8s/namespaces/
kubectl apply -f k8s/rbac/
kubectl apply -f argocd/projects/platform.yaml
kubectl apply -f argocd/app-of-apps.yaml
```

Set Argo CD `application.instanceLabelKey: argocd.argoproj.io/instance` (see
[gitops.md](gitops.md)).

## 8. First rollout

Argo CD syncs `platform-api-dev` (automated). `staging` follows on merge; `prod` needs a
manual sync.

## 9. Run the pipeline

Push a commit. CI builds, scans, publishes `ghcr.io/OWNER/platform-api:<sha>`, and commits
that tag into `argocd/envs/dev/values.yaml`. Argo CD rolls it out. Promote to staging/prod
by PR.

## 10. Verify

```bash
kubectl -n platform-dev get deploy,svc,ingress,hpa,pdb,networkpolicy
kubectl -n platform-staging argo rollouts get rollout platform-api
curl -s https://platform-api.dev.<your-domain>/api/v1/health
```
