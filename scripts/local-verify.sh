#!/usr/bin/env bash
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

pass=0
fail=0

ok()   { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }

want_none() {
  local desc="$1"; shift
  local hits
  hits="$(grep -RInE "$@" 2>/dev/null || true)"
  if [[ -z "${hits}" ]]; then ok "${desc}"; else bad "${desc}"; printf '%s\n' "${hits}" | sed 's/^/       /'; fi
}

want_in_file() {
  local desc="$1" file="$2" pattern="$3"
  if grep -qE "${pattern}" "${file}" 2>/dev/null; then ok "${desc}"; else bad "${desc} (${file})"; fi
}

count_eq() {
  local desc="$1" expected="$2"; shift 2
  local n
  n="$(grep -RIlE "$@" 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "${n}" == "${expected}" ]]; then ok "${desc} (${n})"; else bad "${desc} (found ${n}, want ${expected})"; fi
}

echo "== honesty =="
want_none "no 12-digit AWS account IDs" '[^0-9][0-9]{12}[^0-9]' \
  --include='*.tf' --include='*.yaml' --include='*.yml' --include='*.json' --include='*.groovy' --include='Jenkinsfile'
want_none "no account-scoped AWS ARNs" 'arn:aws:[a-z0-9-]+:[a-z0-9-]*:[0-9]{12}:' \
  --include='*.tf' --include='*.yaml' --include='*.yml' --include='*.json' --include='*.md'
want_none "no deployment / uptime claims" '(deployed to production|in production since|uptime of|serving [0-9]+ (req|rps|requests))' \
  --include='*.md' --include='*.yaml'

echo "== naming contract =="
want_in_file "chart version 0.1.0"      helm/platform-api/Chart.yaml   '^version: 0\.1\.0$'
want_in_file "chart appVersion 0.1.0"   helm/platform-api/Chart.yaml   '^appVersion: "0\.1\.0"$'
want_in_file "pom version 0.1.0"        app/pom.xml                    '<version>0\.1\.0</version>'
want_in_file "image repo default"       helm/platform-api/values.yaml  'repository: ghcr\.io/OWNER/platform-api'
want_in_file "app port 8080"            app/src/main/resources/application.yml 'SERVER_PORT:8080'
want_in_file "mgmt port 8081"           app/src/main/resources/application.yml 'MANAGEMENT_SERVER_PORT:8081'
want_in_file "Dockerfile exposes 8080 8081" docker/Dockerfile          'EXPOSE 8080 8081'

echo "== argo cd wiring =="
count_eq "3 Applications name platform-api-<env>" 3 'name: platform-api-(dev|staging|prod)' --include='*.yaml'
want_none "no targetRevision other than HEAD in argocd" 'targetRevision: (?!HEAD)\S+' --include='*.yaml' argocd
for env in dev staging prod; do
  want_in_file "app ${env} chart path"     "argocd/apps/platform-api-${env}.yaml" 'path: helm/platform-api'
  want_in_file "app ${env} releaseName"    "argocd/apps/platform-api-${env}.yaml" 'releaseName: platform-api'
  want_in_file "app ${env} values ref"     "argocd/apps/platform-api-${env}.yaml" "\\\$values/argocd/envs/${env}/values\\.yaml"
  want_in_file "app ${env} namespace"      "argocd/apps/platform-api-${env}.yaml" "namespace: platform-${env}"
  want_in_file "env ${env} environment"    "argocd/envs/${env}/values.yaml"       "^environment: ${env}$"
done

echo "== rollouts toggle =="
want_in_file "dev rollouts off"     argocd/envs/dev/values.yaml     'enabled: false'
want_in_file "staging rollouts on"  argocd/envs/staging/values.yaml 'enabled: true'
want_in_file "prod rollouts on"     argocd/envs/prod/values.yaml    'enabled: true'
want_in_file "deployment gated"     helm/platform-api/templates/deployment.yaml 'if not \.Values\.argoRollouts\.enabled'
want_in_file "rollout gated"        helm/platform-api/templates/rollout.yaml    'if \.Values\.argoRollouts\.enabled'
want_in_file "hpa target follows toggle" helm/platform-api/templates/hpa.yaml   'if \.Values\.argoRollouts\.enabled'

echo "== environments =="
want_none "no stray environment names" '\b(qa|uat|preprod|production)\b' \
  --include='*.yaml' --include='*.yml' --include='*.tf' argocd k8s terraform helm

echo
echo "checks passed: ${pass}   failed: ${fail}"
[[ ${fail} -eq 0 ]]
