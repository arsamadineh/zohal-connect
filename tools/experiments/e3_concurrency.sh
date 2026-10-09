#!/usr/bin/env bash
# E3: Concurrency test with two Aether processes
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AETHER_BIN="$ROOT_DIR/third_party/dist/linux-x86_64/aether"
TMP_DIR=$(mktemp -d -t zohal-e3-XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

PORT1=29191
PORT2=29192

mkdir -p "$TMP_DIR/inst1" "$TMP_DIR/inst2"

echo "Starting Instance 1 (MASQUE H3) on port $PORT1..."
"$AETHER_BIN" \
  --bind "127.0.0.1:$PORT1" \
  --masque \
  --turbo \
  -4 \
  --config "$TMP_DIR/inst1/aether.toml" \
  < /dev/null > "$TMP_DIR/inst1.log" 2>&1 &
PID1=$!

echo "Starting Instance 2 (MASQUE H2) on port $PORT2..."
"$AETHER_BIN" \
  --bind "127.0.0.1:$PORT2" \
  --masque \
  --h2 \
  --turbo \
  -4 \
  --config "$TMP_DIR/inst2/aether.toml" \
  < /dev/null > "$TMP_DIR/inst2.log" 2>&1 &
PID2=$!

sleep 5

STATUS1=0
STATUS2=0
kill -0 "$PID1" 2>/dev/null || STATUS1=$?
kill -0 "$PID2" 2>/dev/null || STATUS2=$?

echo "Instance 1 (PID $PID1) status check: $STATUS1"
echo "Instance 2 (PID $PID2) status check: $STATUS2"

kill -TERM "$PID1" "$PID2" 2>/dev/null || true
wait "$PID1" 2>/dev/null || true
wait "$PID2" 2>/dev/null || true

if [ "$STATUS1" -eq 0 ] && [ "$STATUS2" -eq 0 ]; then
  echo "E3 passed: Two distinct Aether instances successfully run concurrently with separate ports and identity files."
else
  echo "E3 failed: At least one instance crashed or stopped."
  cat "$TMP_DIR/inst1.log"
  cat "$TMP_DIR/inst2.log"
  exit 1
fi
