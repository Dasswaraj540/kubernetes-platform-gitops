# CI/CD

Jenkins (`ci/Jenkinsfile`) is the reference pipeline. GitHub Actions
(`.github/workflows/ci.yml`) mirrors it. Both call the shared scripts in `scripts/` so the
two cannot drift on the parts that matter (image scan, GitOps tag bump).

## Stages

| # | Stage | Command (essentials) |
|---|---|---|
| 1 | Checkout | `git rev-parse --short=7 HEAD` → `IMAGE_TAG` |
| 2 | Dependency resolution | `./mvnw -B -ntp dependency:go-offline` |
| 3 | Build | `./mvnw -B -ntp -DskipTests clean package` |
| 4 | Unit tests | `./mvnw -B -ntp test` (surefire report published) |
| 5 | Static analysis | `./mvnw -B -ntp -DskipTests verify -Pstatic-analysis` (SpotBugs) |
| 6 | Dependency / security scan | `dependency:copy-dependencies` then `trivy fs` over `app/target/deps` — HIGH/CRITICAL, `--ignore-unfixed`, ignore list `security/dependencies/.trivyignore` |
| 7 | Container image build | `docker build -f docker/Dockerfile --build-arg GIT_SHA=$IMAGE_TAG -t $IMAGE_REPO:$IMAGE_TAG app` |
| 8 | Container image scan | `scripts/image-scan.sh $IMAGE_REPO:$IMAGE_TAG` — Trivy, HIGH/CRITICAL, `--ignore-unfixed`, ignore list `security/images/.trivyignore` |
| 9 | Image tagging | `$IMAGE_REPO:$IMAGE_TAG` (+ a `build-<n>` convenience tag in Jenkins) |
| 10 | Registry publishing | `docker push $IMAGE_REPO:$IMAGE_TAG` to `ghcr.io` |
| 11 | GitOps update | `scripts/update-gitops-tag.sh` writes `.image.tag` in `argocd/envs/dev/values.yaml`, commits to `main` |

`IMAGE_REPO` is `ghcr.io/OWNER/platform-api`. `IMAGE_TAG` is the 7-character git short SHA —
the same value in `ci/Jenkinsfile`, `.github/workflows/ci.yml`, and
`scripts/update-gitops-tag.sh`.

## Credentials

Nothing is hardcoded.

| Secret | Jenkins | GitHub Actions |
|---|---|---|
| Registry push | `credentials('platform-registry')` → `REGISTRY_CREDENTIALS_USR/_PSW` | `secrets.GITHUB_TOKEN` via `docker/login-action` |
| GitOps commit token | `credentials('platform-gitops-token')` → `GITOPS_TOKEN` | `secrets.GITOPS_TOKEN` (falls back to `GITHUB_TOKEN`) |
| AWS (optional ECR) | not used | OIDC: `secrets.AWS_GHA_OIDC_ROLE_ARN`, `vars.AWS_REGION` |

## Promotion

Stage 11 advances **dev only**. Promotion to staging and prod is a pull request that copies
the tested `image.tag` value from `argocd/envs/dev/values.yaml` into
`argocd/envs/staging/values.yaml`, then prod — reviewed like any code change. See
[gitops.md](gitops.md).

## The ECR path

`.github/workflows/ci.yml` has an `ecr-publish` job, disabled by default
(`vars.ENABLE_ECR_PUBLISH != 'true'`). When enabled it assumes the
`AWS_GHA_OIDC_ROLE_ARN` role via OIDC, logs in to ECR, and re-pushes the image. The
committed default keeps everything on GHCR so no AWS account is required. Switching to ECR
means: enable the job, point `image.repository` at the `ecr` module's `repository_url`
output, and grant the CI role via `terraform/modules/iam` (`gha_oidc_enabled = true`).

## Validating the Jenkinsfile without a build

```bash
curl -s -X POST -F "jenkinsfile=<ci/Jenkinsfile" \
  https://<your-jenkins>/pipeline-model-converter/validate
```

## Local equivalents

```bash
scripts/build.sh                       # ./mvnw -B -ntp verify
scripts/image-scan.sh ghcr.io/OWNER/platform-api:dev
scripts/lint.sh                        # helm lint + kubeconform + yamllint + tf fmt + consistency
```
