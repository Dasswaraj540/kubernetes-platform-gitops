#!/usr/bin/env bash
set -euo pipefail

: "${IMAGE_TAG:?IMAGE_TAG is required (git short SHA)}"
GITOPS_ENV="${GITOPS_ENV:-dev}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALUES_FILE="${VALUES_FILE:-${REPO_ROOT}/argocd/envs/${GITOPS_ENV}/values.yaml}"

if ! [[ "${IMAGE_TAG}" =~ ^[0-9a-f]{7,40}$ ]]; then
  echo "IMAGE_TAG must be a lowercase hex git SHA (normally 7 chars): ${IMAGE_TAG}" >&2
  exit 1
fi

if [[ ! -f "${VALUES_FILE}" ]]; then
  echo "values file not found: ${VALUES_FILE}" >&2
  exit 1
fi

if ! command -v yq >/dev/null 2>&1; then
  echo "yq is required (https://github.com/mikefarah/yq)" >&2
  exit 1
fi

TAG="${IMAGE_TAG}" yq -i '.image.tag = strenv(TAG)' "${VALUES_FILE}"
echo "set .image.tag = ${IMAGE_TAG} in ${VALUES_FILE}"
