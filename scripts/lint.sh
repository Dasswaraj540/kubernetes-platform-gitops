#!/usr/bin/env bash
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

status=0
step() { echo; echo "==> $*"; }
mark() { [[ $1 -eq 0 ]] || status=1; }

if command -v helm >/dev/null 2>&1; then
  for env in dev staging prod; do
    step "helm lint (${env})"
    helm lint helm/platform-api -f "argocd/envs/${env}/values.yaml"
    mark $?
    if command -v kubeconform >/dev/null 2>&1; then
      step "helm template (${env}) | kubeconform"
      helm template platform-api helm/platform-api -f "argocd/envs/${env}/values.yaml" \
        | kubeconform -strict -ignore-missing-schemas -summary
      mark $?
    fi
  done
else
  echo "helm not found; skipping chart lint/render"
fi

if command -v yamllint >/dev/null 2>&1; then
  step "yamllint"
  yamllint -c .yamllint.yaml argocd k8s observability security .github rollouts
  mark $?
else
  echo "yamllint not found; skipping"
fi

if command -v terraform >/dev/null 2>&1; then
  step "terraform fmt -check"
  terraform fmt -check -recursive terraform
  mark $?
else
  echo "terraform not found; skipping fmt check"
fi

step "static consistency review"
bash scripts/local-verify.sh
mark $?

echo
[[ ${status} -eq 0 ]] && echo "lint: OK" || echo "lint: FAILED"
exit ${status}
