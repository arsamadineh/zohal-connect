#!/usr/bin/env bash
# E1: Subprocess harness with full flags and stdin closed
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AETHER_BIN="$ROOT_DIR/third_party/dist/linux-x86_64/aether"
TMP_DIR=$(mktemp -d -t zohal-e1-XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Running Aether E1 subprocess test..."
PORT=28190

# Full flags, stdin closed
"$AETHER_BIN" \
  --bind "127.0.0.1:$PORT" \
  --masque \
  --turbo \
  -4 \
  --config "$TMP_DIR/aether.toml" \
  < /dev/null > "$TMP_DIR/out.log" 2>&1 &
AETHER_PID=$!

sleep 3
if kill -0 "$AETHER_PID" 2>/dev/null; then
  echo "Aether is running without prompt blocks (PID: $AETHER_PID)."
  kill -TERM "$AETHER_PID" || true
  wait "$AETHER_PID" 2>/dev/null || true
  echo "E1 passed: Aether never blocked on stdin."
else
  echo "Aether exited unexpectedly:"
  cat "$TMP_DIR/out.log"
  exit 1
fi
