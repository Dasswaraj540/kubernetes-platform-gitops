#!/usr/bin/env bash
set -euo pipefail

IMAGE_REF="${1:-${IMAGE_REF:-}}"
if [[ -z "${IMAGE_REF}" ]]; then
  echo "usage: image-scan.sh <image-ref>" >&2
  exit 2
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TRIVY_CONFIG="${TRIVY_CONFIG:-${REPO_ROOT}/security/images/trivy.yaml}"
IGNORE_FILE="${REPO_ROOT}/security/images/.trivyignore"

if ! command -v trivy >/dev/null 2>&1; then
  echo "trivy is required (https://aquasecurity.github.io/trivy)" >&2
  exit 1
fi

args=(image --config "${TRIVY_CONFIG}")
if [[ -f "${IGNORE_FILE}" ]]; then
  args+=(--ignorefile "${IGNORE_FILE}")
fi
args+=("${IMAGE_REF}")

echo "+ trivy ${args[*]}"
exec trivy "${args[@]}"
