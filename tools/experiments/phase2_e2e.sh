#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo "Starting Phase 2 Linux Platform Verification Test"
echo "=================================================="

# Check root or ip capability
if [ "$EUID" -ne 0 ]; then
    echo "Running with unshare netns for isolated test..."
    exec unshare -r -n "$0" "$@"
fi

# 1. Snapshot initial state
ip link > /tmp/ip_link_initial.txt
ip route > /tmp/ip_route_initial.txt
ip rule > /tmp/ip_rule_initial.txt
ip -6 route > /tmp/ip6_route_initial.txt
ip -6 rule > /tmp/ip6_rule_initial.txt

echo "[1/4] Baseline network state recorded."

# 2. Compile zohald release binary
echo "[2/4] Building zohald..."
cargo build --release -p zohald --manifest-path engine/Cargo.toml

ZOHALD_BIN="engine/target/release/zohald"
TEST_DATA="/tmp/zohal_test_data"
TEST_RUN="/tmp/zohal_test_run"
rm -rf "$TEST_DATA" "$TEST_RUN"
mkdir -p "$TEST_DATA" "$TEST_RUN"

export STATE_DIRECTORY="$TEST_DATA"
export RUNTIME_DIRECTORY="$TEST_RUN"

# 3. Test clean lifecycle
echo "[3/4] Testing lifecycle and policy routing..."
"$ZOHALD_BIN" service &
ZOHALD_PID=$!
sleep 0.5

# Connect via IPC
cargo test -p zohal-engine --manifest-path engine/Cargo.toml --lib -- ipc_client::tests::test_ipc_server_client_roundtrip --nocapture

# Stop zohald cleanly
kill -TERM "$ZOHALD_PID" || true
wait "$ZOHALD_PID" || true

# Test emergency cleanup
"$ZOHALD_BIN" cleanup

# Verify zero rule/route/device leaks
ip link > /tmp/ip_link_after.txt
ip route > /tmp/ip_route_after.txt
ip rule > /tmp/ip_rule_after.txt
ip -6 route > /tmp/ip6_route_after.txt
ip -6 rule > /tmp/ip6_rule_after.txt

diff -u /tmp/ip_link_initial.txt /tmp/ip_link_after.txt || { echo "Link leak detected!"; exit 1; }
diff -u /tmp/ip_route_initial.txt /tmp/ip_route_after.txt || { echo "Route leak detected!"; exit 1; }
diff -u /tmp/ip_rule_initial.txt /tmp/ip_rule_after.txt || { echo "Rule leak detected!"; exit 1; }
diff -u /tmp/ip6_route_initial.txt /tmp/ip6_route_after.txt || { echo "IPv6 Route leak detected!"; exit 1; }
diff -u /tmp/ip6_rule_initial.txt /tmp/ip6_rule_after.txt || { echo "IPv6 Rule leak detected!"; exit 1; }

echo "[3/4] Verified: Clean lifecycle leaves ZERO leaked rules, routes, or devices."

# 4. Test crash recovery (kill -9 mid-run)
echo "[4/4] Testing crash recovery after kill -9..."
"$ZOHALD_BIN" service &
ZOHALD_PID=$!
sleep 0.5

# Abrupt kill -9
kill -9 "$ZOHALD_PID" || true
wait "$ZOHALD_PID" 2>/dev/null || true

# Restart zohald which triggers journal recovery
"$ZOHALD_BIN" cleanup

ip link > /tmp/ip_link_crash.txt
ip route > /tmp/ip_route_crash.txt
ip rule > /tmp/ip_rule_crash.txt

diff -u /tmp/ip_link_initial.txt /tmp/ip_link_crash.txt || { echo "Post-crash Link leak!"; exit 1; }
diff -u /tmp/ip_route_initial.txt /tmp/ip_route_crash.txt || { echo "Post-crash Route leak!"; exit 1; }
diff -u /tmp/ip_rule_initial.txt /tmp/ip_rule_crash.txt || { echo "Post-crash Rule leak!"; exit 1; }

echo "[4/4] Verified: Crash recovery restored 100% clean state."
echo "=================================================="
echo "Phase 2 Linux Platform Verification PASSED!"
echo "=================================================="
