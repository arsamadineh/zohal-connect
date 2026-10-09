#!/usr/bin/env bash
# E6: Linux policy-routing loop prevention validation in network namespace
set -euo pipefail

unshare -rn bash << 'EOF'
set -euo pipefail

# 1. Bring up loopback
ip link set lo up

# 2. Create simulated physical interface eth0
ip link add eth0 type dummy
ip link set eth0 up
ip addr add 192.168.1.100/24 dev eth0
ip route add default via 192.168.1.1 dev eth0

# 3. Create simulated TUN device zohal0
ip tuntap add mode tun dev zohal0
ip link set zohal0 up
ip addr add 198.18.0.1/30 dev zohal0

# 4. Apply Zohal policy routing
M="0x5a48"
T="100"
P1="1000"
P2="2000"
P3="3000"

ip route add default dev zohal0 table "$T"
ip rule add pref "$P1" fwmark "$M" lookup main
ip rule add pref "$P2" lookup main suppress_prefixlength 0
ip rule add pref "$P3" lookup "$T"

# 5. Verify Route Lookups
echo "Testing route lookups..."

# A: Unmarked public internet traffic -> MUST go to zohal0
ROUTE_UNMARKED=$(ip route get 8.8.8.8)
echo "Unmarked traffic (8.8.8.8): $ROUTE_UNMARKED"
if ! echo "$ROUTE_UNMARKED" | grep -q "dev zohal0"; then
  echo "FAIL: Unmarked traffic did not route to zohal0" >&2
  exit 1
fi

# B: Marked Aether sockets (fwmark 0x5a48) -> MUST bypass to physical eth0 (table main)
ROUTE_MARKED=$(ip route get 8.8.8.8 mark "$M")
echo "Marked traffic (8.8.8.8 mark $M): $ROUTE_MARKED"
if ! echo "$ROUTE_MARKED" | grep -q "dev eth0"; then
  echo "FAIL: Marked traffic did not bypass to eth0" >&2
  exit 1
fi

# C: LAN traffic (192.168.1.50) -> MUST stay on local eth0 via suppress_prefixlength 0
ROUTE_LAN=$(ip route get 192.168.1.50)
echo "LAN traffic (192.168.1.50): $ROUTE_LAN"
if ! echo "$ROUTE_LAN" | grep -q "dev eth0"; then
  echo "FAIL: LAN traffic did not stay on eth0" >&2
  exit 1
fi

echo "E6 validation PASSED: Policy routing correctly routes unmarked to TUN, marked to eth0, and LAN to eth0."
EOF
