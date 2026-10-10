#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Checking for stubs, placeholders and forbidden patterns..."
ERRORS=0

# Pattern 1: TODO|FIXME|XXX|unimplemented!|todo!|placeholder|mock|dummy|fake_
BANNED_PATTERN="TODO|FIXME|XXX|unimplemented!|todo!|placeholder|mock|dummy|fake_"
STUB_MATCHES=$(grep -rnE "$BANNED_PATTERN" \
  "$ROOT_DIR/engine/crates"/*/src \
  "$ROOT_DIR/app/lib" \
  "$ROOT_DIR/app/android/app/src/main" \
  2>/dev/null | grep -v "/tests/" | grep -v "_test.rs" || true)

if [ -n "$STUB_MATCHES" ]; then
  echo "[ERROR] Found banned stub/placeholder keywords:"
  echo "$STUB_MATCHES"
  ERRORS=$((ERRORS + 1))
fi

# Pattern 2: .unwrap() / .expect( in non-test Rust
UNWRAP_MATCHES=$(python3 -c "
import os
import re

root = '$ROOT_DIR'
crates_dir = os.path.join(root, 'engine', 'crates')
p_unwrap = re.compile(r'\.(unwrap|expect)\(')

hits = []
for crate in os.listdir(crates_dir):
    src_dir = os.path.join(crates_dir, crate, 'src')
    if not os.path.isdir(src_dir):
        continue
    for dirpath, _, filenames in os.walk(src_dir):
        for f in filenames:
            if f.endswith('.rs') and not f.endswith('_test.rs'):
                fpath = os.path.join(dirpath, f)
                with open(fpath, 'r', encoding='utf-8') as fh:
                    in_test_mod = False
                    for idx, line in enumerate(fh, 1):
                        stripped = line.strip()
                        if 'mod tests' in stripped or '#[cfg(test)]' in stripped:
                            in_test_mod = True
                        if in_test_mod:
                            continue
                        if p_unwrap.search(line):
                            hits.append(f'{fpath}:{idx}: {stripped}')
if hits:
    print('\n'.join(hits))
")

if [ -n "$UNWRAP_MATCHES" ]; then
  echo "[ERROR] Found unwrap/expect in non-test Rust:"
  echo "$UNWRAP_MATCHES"
  ERRORS=$((ERRORS + 1))
fi

if [ "$ERRORS" -gt 0 ]; then
  echo "Stub check FAILED."
  exit 1
fi

echo "Zero stubs or unwrap/expect found in production code."
