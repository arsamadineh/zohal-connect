# Aether Verified Log Patterns

Derived from upstream source code analysis (`third_party/aether-src/aether/src/`) and live runs of Aether v2.3.0.

## 1. Starting Scan
- MASQUE: `[*] hunting for a working MASQUE gateway (deep connect-ip + data-plane verification)`
- WireGuard: `[*] hunting for a working WireGuard endpoint (handshake + data-plane verification, aethernoize='<profile>')`
- Prober details: `[*] scan mode=<mode> ip=<v4|v6> candidates=<N> ports=[...] concurrency=<C> per_probe=<S> budget=<B>`

## 2. Candidate Found & Validation
- MASQUE H3: `[*] validating masque data-plane before exposing socks5`
- MASQUE H2: `[h2] validating data-plane (end-to-end probe) before exposing socks5`
- WireGuard: `[*] validating WireGuard tunnel with <peer> (handshake + data-plane) before exposing socks5...`

## 3. Data-Plane Validated
- MASQUE H3: `[*] masque data-plane round-trip <round>/<total> confirmed`
- MASQUE H2: `[h2] data-plane round-trip <round>/<total> confirmed`
- WireGuard: `[+] profile '<profile>' passed handshake + data-plane (rtt <duration>)`

## 4. Listening
- SOCKS5 listener: `[+] socks5 server listening on <listen_addr>`
- HTTP proxy listener: `[+] http proxy listening on <listen_addr>`

## 5. Tunnel Lost / Health
- Drop / Timeout: `[-] connection dropped, reconnecting in <secs>`
- WireGuard dead: `silence on a wireguard tunnel before it counts as dead`

## 6. Reconnect
- MASQUE reconnect: `reconnecting in <secs>`
- Prober retry: `prober: no clean endpoint found; rescanning shortly`

## 7. Identity Replaced / Provisioned
- MASQUE: `[+] provisioned and saved new masque identity to <path>`
- WireGuard: `[+] provisioned and saved new warp identity to <path>`
- Device info: `[+] identity ready: device=<uuid> ipv4=<ip> ipv6=<ip>`

## 8. Registration Failure
- Failure: `[-] failed to provision account: <error>`
