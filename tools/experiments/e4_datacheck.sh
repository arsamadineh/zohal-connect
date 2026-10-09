#!/usr/bin/env bash
# E4: Cloudflare WARP data check probe
set -euo pipefail

PORT="${1:-1819}"
URL="https://1.1.1.1/cdn-cgi/trace"

echo "Probing Cloudflare trace through SOCKS5 proxy on 127.0.0.1:$PORT..."

RESPONSE=$(curl -s --connect-timeout 5 -m 8 -x "socks5h://127.0.0.1:$PORT" "$URL" || true)

if [ -z "$RESPONSE" ]; then
  echo "Probe failed or proxy not accepting traffic."
  exit 1
fi

echo "Trace Response:"
echo "$RESPONSE"

if echo "$RESPONSE" | grep -q "warp=on\|warp=plus"; then
  echo "E4 verification PASSED: warp=on confirmed."
  IP=$(echo "$RESPONSE" | grep "^ip=" | cut -d= -f2)
  LOC=$(echo "$RESPONSE" | grep "^loc=" | cut -d= -f2)
  COLO=$(echo "$RESPONSE" | grep "^colo=" | cut -d= -f2)
  echo "Detected IP: $IP, Location: $LOC, Colo: $COLO"
  exit 0
else
  echo "E4: Reply did not contain warp=on/warp=plus."
  exit 2
fi
