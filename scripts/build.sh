#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}/app"

chmod +x mvnw
exec ./mvnw -B -ntp "${@:-verify}"
