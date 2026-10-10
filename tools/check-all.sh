#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1 && [ -d "/opt/flutter/bin" ]; then
  export PATH="/opt/flutter/bin:$PATH"
fi

echo "== rust"
(cd engine && cargo fmt --all -- --check && cargo clippy --workspace --all-targets -- -D warnings && cargo test --workspace)

echo "== flutter"
(cd app && dart format --set-exit-if-changed lib test && flutter analyze && flutter test)

echo "== lints"
./tools/lint-persian.sh
./tools/lint-no-stubs.sh

echo "ALL CHECKS PASSED"
