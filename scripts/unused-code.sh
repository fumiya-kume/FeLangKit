#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v periphery >/dev/null 2>&1; then
  echo "periphery not found. Install with: brew install peripheryapp/periphery/periphery" >&2
  exit 1
fi

cd "$ROOT_DIR"

# Note:
# - --retain-public: Avoid false positives for library APIs used externally
# - --exclude-tests: Focus on production code
periphery scan --retain-public --exclude-tests --relative-results "$@"

