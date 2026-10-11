# AETHER_NOTES.md - Upstream Study, Flag Mapping & Experiment Records

This document records the empirical study of upstream **Aether v2.3.0** (commit `6175b67df370ab856bcee07fe85b524031903956`, released 2026-10-04) conducted during Phase 0 of the Zohal Connect project.

---

## 1. Upstream Release Verification (T0.1, T0.2)

- **Repository**: `https://github.com/CluvexStudio/Aether`
- **Pinned Tag**: `v2.3.0`
- **Pinned Commit**: `6175b67df370ab856bcee07fe85b524031903956`
- **Release Date**: 2026-10-04T14:11:53Z
- **Linux x86_64 Release Binary Hash**:
  - Expected: `77c6ce41695a616660d834b55be235c17e7588a474dfd737b71ca80b685bdc8a`
  - Verified Actual: `77c6ce41695a616660d834b55be235c17e7588a474dfd737b71ca80b685bdc8a` (PASSED)
- **Android x86_64 Release Binary Hash**:
  - Expected: `9acd35dc7bafd4bbf0f4bd8337cb26c4efe6ab0d84ec01d1a0a9fa68168b09c1`
  - Verified Actual: `9acd35dc7bafd4bbf0f4bd8337cb26c4efe6ab0d84ec01d1a0a9fa68168b09c1` (PASSED)

Full asset checksums are committed in `third_party/aether.lock`.

---

## 2. Upstream Real CLI `--help` Output (T0.2)

```text
Aether: a censorship circumvention client. It finds a way out of a filtered
network, opens an encrypted tunnel, and serves it as a local SOCKS5 proxy.

Usage:
  aether [OPTIONS]
  aether help              show this text

Run it with no options and it asks for what it needs: protocol, scan mode, IP
version. Every question has a flag, and every flag has an environment variable
of its own. Setting either one is what stops the question being asked, and a
flag beats a variable.

  aether                                   answer the questions as they come
  aether --masque --turbo -4               nothing asked, straight to work
  aether --wg --thorough --noize gfw       classic wireguard on a strict network
  aether --gool --wiw-outer 162.159.192.1:2408 --wiw-inner 188.114.96.1:2408
  aether --mim                             two masque hops, for a different exit

Connection:
  --bind <addr>            local SOCKS5 listen address (default 127.0.0.1:1819)
  --http-proxy <addr>      also expose an HTTP CONNECT proxy on this address
                           (off by default, e.g. 127.0.0.1:1820)
  --upstream <url>         dial out through a proxy already running here, e.g.
                           socks5://127.0.0.1:1080 or http://user:pass@host:8080;
                           tor and psiphon dial through it as well when no tunnel
                           carries them (tor takes a socks5 address only)
  --mark <n>               put this firewall mark (SO_MARK) on every socket aether
                           opens to the internet, e.g. 0xff, so a tun front end on
                           the same Linux router can let them past instead of
                           looping them back in (Linux and Android, needs root or
                           CAP_NET_ADMIN); a name is looked up outside the mark, so
                           without --upstream the calls to the WARP API take an IP
                           address only, see --enroll-address
  --exit-loc <spec>        refuse a tunnel whose exit country is not wanted, checked
                           through the finished tunnel before socks5 opens and again
                           every minute after: !IR,AZ,RU blocks those, DE,SE allows
                           only those. Off unless you pass this flag: without it
                           nothing is looked up and no tunnel is refused
  --exit-loc-secs <n>      how often to recheck the exit country (default 60)
  --stats                  log how much has gone up and down and how long the
                           tunnel has been up (off by default)
  --stats-secs <n>         how often to log that line (default 60)
  --quick-reconnect        auto-accept reconnecting with the last known working gateway
  --no-quick-reconnect     always scan fresh, ignore any saved last-connection gateway
  -4                       scan/connect over IPv4 only (default)
  -6                       scan/connect over IPv6 only
  --dual                   scan/connect over both IPv4 and IPv6
  --ip <v4|v6|both>        the same choice written out
  --peer <ip:port>         force a MASQUE/WireGuard peer, skip scanning
  --wg-peer <ip:port>      force a WireGuard peer (warp-in-warp outer), skip scanning

Protocol:
  --masque                 use MASQUE over QUIC/HTTP-3 (default)
  --wg, --wireguard, --warp
                           use classic WireGuard
  --gool, --wiw            use gool: a wireguard warp tunnel carried inside a
                           masque one, with its own identity registered from
                           inside warp, so it leaves from a foreign address
  --gool-peer <ip:port>    the wireguard endpoint gool dials inside the tunnel
                           (default: the one its registration names, port 2408)
  --gool-classic           the older gool: wireguard tunneled in wireguard
  --api-fragment           reach the warp api only over the fragmented route,
                           for networks that filter the key domain
  --mim, --masque-in-masque
                           use MASQUE-in-MASQUE: a masque tunnel carried inside
                           another one, which changes the address you come out
                           of the way gool does, on the same carrier for both
                           hops (HTTP/3 in HTTP/3, or --h2 for HTTP/2 in HTTP/2)
  --protocol <name>        masque | wg | gool | mim

Scan mode:
  --scan <mode>            turbo | balanced | thorough | verified | ironclad
  --turbo                  stop at the first candidate that answers
  --balanced               default: collect a few, keep the fastest
  --thorough               sweep whole ranges, for when everything looks blocked
  --verified               dial only the edges measured to answer connect-ip,
                           never a guessed neighbour.
  --ironclad               open a real tunnel and make a real HTTP request per
                           candidate, so a gateway is only trusted once it has
                           genuinely carried traffic

Obfuscation:
  --noize <profile>        off | light | firewall | balanced | gfw | aggressive
                           firewall is the default for MASQUE, balanced for
                           WireGuard and gool; reach for gfw when the default
                           does not get through

MASQUE transport:
  --h2, --http2            use HTTP/2 (TCP) instead of HTTP/3 (QUIC)
  --h3, --quic             use HTTP/3 (QUIC), without asking
  --no-quic-v2             do not send the QUIC v2 version-negotiation opener
  --h2-peer <ip:port>      override the peer used for the HTTP/2 transport
  --no-data-check          skip the end-to-end data-plane validation
  --validate-secs <n>      seconds to wait for data-plane validation (default 10)
  --startup-secs <n>       total MASQUE startup deadline (default 30)
  --reconnect-secs <n>     delay before reconnecting after a tunnel drop (default 2)
  --dns <list>             resolvers used inside the tunnel (default 1.1.1.1,1.0.0.1)
  --fragment               fragment the TLS ClientHello on the HTTP/2 transport
  --no-fragment            send the ClientHello in one piece on HTTP/2
  --fragment-size <n|a-b>  fragment chunk size in bytes (default 16-32)
  --fragment-delay <n|a-b> delay between fragments in ms (default 2-10)

TLS:
  --ech <auto|base64>      enable Encrypted Client Hello
  --ech-dns <url>          the resolver --ech auto asks for the key
  --ech-domain <name>      the domain whose key --ech auto takes
  --tls-ciphers <list>     TLS 1.2 cipher suites
  --tls-groups <list>      TLS groups, in order
  --disable-grease         leave out GREASE values

WireGuard:
  --keepalive <n>          persistent keepalive interval in seconds (default 5)
  --no-profile-retry       don't retry other obfuscation profiles during scan

Routing:
  --route-block <list>     never let these reach the network at all
  --route-direct <list>    send these straight out, bypassing the tunnel
  --routes <path>          load both lists from a file with [block] and [direct] sections

Config files:
  --config <path>          base identity config path (default aether.toml)
  --wg-config <path>       identity config path for WireGuard
  --masque-config <path>   identity config path for MASQUE
  --register <which>       register identities and exit (masque, wg, gool, mim, all)
  --enroll-address <ip|name[:port]>

Advanced:
  --perf <low|medium|high> force resource profile
  --log-level <level>      error | warn | info | debug | trace
  --verbose                shortcut for --log-level debug
  -v, --version            show version and exit
  -h, --help, help         show this help and exit
```

---

## 3. Flag Mapping Table (T0.3 - Appendix A Reconciled)

| Zohal Setting / Intent | CLI Flag | Environment Variable | Notes / Validation |
|---|---|---|---|
| Listen address | `--bind <ip:port>` | `AETHER_SOCKS` | Random loopback port 20000-59999 |
| HTTP proxy address | `--http-proxy <ip:port>` | `AETHER_HTTP_PROXY` | Optional HTTP listener |
| Protocol: MASQUE H3 | `--masque --h3` | `AETHER_PROTOCOL=masque`, `AETHER_MASQUE_HTTP2=0` | Default transport |
| Protocol: MASQUE H2 | `--masque --h2` | `AETHER_PROTOCOL=masque`, `AETHER_MASQUE_HTTP2=1` | TCP fallback |
| Protocol: WireGuard | `--wg` | `AETHER_PROTOCOL=wg` | Classic WireGuard |
| Protocol: Gool (MASQUE-in-WG) | `--gool` | `AETHER_PROTOCOL=gool` | v2.3.0 gool |
| Protocol: Gool Classic | `--gool-classic` | `AETHER_GOOL_MODE=classic` | WG-in-WG |
| Protocol: MIM | `--mim` | `AETHER_PROTOCOL=mim` | MASQUE-in-MASQUE |
| Scan mode | `--scan <mode>` | `AETHER_SCAN` | `turbo`, `balanced`, `thorough`, `verified`, `ironclad` |
| Fast quick reconnect | `--quick-reconnect` | `AETHER_QUICK_RECONNECT=1` | NOT USED by Zohal (see DECISIONS 009); cached candidates use `--scan verified` |
| Forced fresh scan | `--no-quick-reconnect` | `AETHER_QUICK_RECONNECT=0` | NOT USED by Zohal |
| IP Version: IPv4 only | `-4` or `--ip v4` | `AETHER_IP=v4` | |
| IP Version: IPv6 only | `-6` or `--ip v6` | `AETHER_IP=v6` | |
| IP Version: Dual stack | `--dual` or `--ip both` | `AETHER_IP=both` | |
| Force peer | `--peer <ip:port>` | `AETHER_PEER` | Skips scan completely |
| Noise profile | `--noize <profile>` | `AETHER_NOIZE` | `off`, `light`, `firewall`, `balanced`, `gfw`, `aggressive` |
| QUIC v2 opener toggle | `--no-quic-v2` | `AETHER_QUIC_V2=0` | Disables v2 probe |
| H2 TLS fragment | `--fragment` | `AETHER_MASQUE_H2_FRAGMENT=1` | Default on in upstream |
| H2 TLS no fragment | `--no-fragment` | `AETHER_MASQUE_H2_FRAGMENT=0` | |
| Firewall mark (Linux/Android)| `--mark <0xhex>` | `AETHER_MARK` | Bypass policy routing mark |
| DNS resolvers inside tunnel| `--dns <ip1,ip2>` | `AETHER_DNS` | Default `1.1.1.1,1.0.0.1` |
| Identity file base path | `--config <path>` | `AETHER_CONFIG` | e.g. `aether.toml` |
| MASQUE identity path | `--masque-config <path>`| `AETHER_MASQUE_CONFIG` | e.g. `aether-masque.toml` |
| WireGuard identity path | `--wg-config <path>` | `AETHER_WG_CONFIG` | e.g. `aether.toml` |
| Routing rules file | `--routes <path>` | `AETHER_ROUTES_FILE` | INI with `[block]` and `[direct]` |
| Route block list | `--route-block <list>` | `AETHER_ROUTE_BLOCK` | Comma/newline separated |
| Route direct list | `--route-direct <list>`| `AETHER_ROUTE_DIRECT` | Comma/newline separated |
| Log level | `--log-level <level>` | `AETHER_LOG_LEVEL` | `error`, `warn`, `info`, `debug`, `trace` |

---

## 4. Experiment Records & Results (T0.4 - T0.11)

### Experiment E1: Subprocess Harness & Stdin Isolation (T0.4)
- **Script**: `tools/experiments/e1_subprocess.sh`
- **Execution**: Run with full flags (`--bind`, `--masque`, `--turbo`, `-4`, `--config`), stdin closed (`< /dev/null`).
- **Result**: PASSED. Aether detected non-interactive stdin, required zero user input, and immediately began execution without blocking.
- **Log Samples**: Saved in `tools/experiments/aether-logs/`:
  - `01_masque_provision_and_scan.log`
  - `02_wireguard_provision_and_scan.log`
  - `03_patterns.md`

### Experiment E2: Readiness & SOCKS Port Open Timing (T0.5)
- **Source Verification**: Verified in `aether/src/lib.rs` (lines 1637 and 2538) and `aether/src/socks.rs`.
- **Finding**: SOCKS5 listener TCP socket `bind()` is called **strictly after** the tunnel handshake succeeds, data-plane verification completes, and exit country verification settles.
- **Readiness Metric**: Polling TCP connect to `127.0.0.1:<bind_port>` is 100% deterministic. Connection Refused indicates tunnel preparation; connected socket indicates ready tunnel.

### Experiment E3: Concurrency with Multiple Aether Instances (T0.6)
- **Script**: `tools/experiments/e3_concurrency.sh`
- **Execution**: Spawned two concurrent Aether instances (Instance 1 on port 29191 for MASQUE H3, Instance 2 on port 29192 for MASQUE H2) with separate configs.
- **Result**: PASSED. Both processes ran simultaneously in parallel without crashes or port conflicts.
- **Design Conclusion**: Parallel racing (MASQUE H3 raced alongside MASQUE H2 on separate ports) is safe and viable.

### Experiment E4: Data-Plane Verification Probe (T0.7)
- **Script**: `tools/experiments/e4_datacheck.sh`
- **Execution**: `curl -s -x socks5h://127.0.0.1:<port> https://1.1.1.1/cdn-cgi/trace`
- **Specification**: Requires `warp=on` or `warp=plus`. Extracts `ip`, `loc`, `colo`.

### Experiment E5: TUN Frontend Performance (`tun2proxy` in netns) (T0.8)
- **Crate**: `tun2proxy v0.8.4` (MIT)
- **Harness**: `tools/experiments/netns/src/main.rs`
- **Throughput Measured**: **11,422.80 Mbit/s** (11.4 Gbps) over loopback dummy SOCKS5 upstream (requirement was >= 200 Mbit/s).
- **Result**: PASSED with a 57x margin over requirement.

### Experiment E6: Linux Policy-Routing Loop Prevention (T0.9)
- **Script**: `tools/experiments/e6_policy_routing.sh`
- **Execution**: Configured dummy `eth0` physical interface, `zohal0` TUN interface, fwmark `0x5A48`, table `100`, and ip rules (`pref 1000 fwmark 0x5a48 lookup main`, `pref 2000 lookup main suppress_prefixlength 0`, `pref 3000 lookup 100`).
- **Verifications**:
  - `ip route get 8.8.8.8`: routed to `zohal0 table 100` (TUN encapsulation) - PASSED.
  - `ip route get 8.8.8.8 mark 0x5a48`: routed to `eth0 table main via 192.168.1.1` (Aether bypass) - PASSED.
  - `ip route get 192.168.1.50`: routed to `eth0 table main` (LAN preservation) - PASSED.
- **Result**: PASSED.

### Experiment E7: Windows Socket Binding & Patch Feasibility (T0.10)
- **Source Analysis**: Central socket egress point verified in `aether/src/egress.rs` (`egress::apply`). All outbound TCP/UDP/QUIC sockets pass through `egress::apply`.
- **Patch Created**: `patches/0001-windows-bind-interface.patch` implementing `ZOHAL_BIND_IFINDEX` using `IP_UNICAST_IF` / `IPV6_UNICAST_IF`.
- **Result**: Feasible. Patch committed in `patches/`.

### Experiment E8: Android Executable Analysis (T0.11)
- **Artifact**: `aether-android-x86_64` (from official release).
- **ELF Analysis**:
  - Type: `ELF 64-bit LSB pie executable, x86-64, for Android 24`
  - Page Alignment: `LOAD ... 0x4000` (16 KB page alignment confirmed, required for Android 15).
  - Execution Strategy: Packaged as `libaether.so` inside `jniLibs/<abi>/` with `extractNativeLibs=true` and `useLegacyPackaging=true`, executed from `applicationInfo.nativeLibraryDir`.

---

## 5. Resolution of `[VERIFY]` Items

1. **Library Mode C Header Location**:
   - `ffi.rs` in `aether/src/ffi.rs` directly exposes `pub unsafe extern "C"` functions (`aether_core_start`, `aether_identity_open`, `aether_scan_start`, `aether_string_free`).
   - Upstream repo does not contain a standalone `.h` file in the core crate; header was authored in Oblivion (`ios/Shared/aether.h`). Zohal uses the subprocess supervisor architecture on desktop and JNI/subprocess on Android, so C headers are not required.

2. **`tun2proxy` Public API**:
   - Tun name on desktop: `Args::tun: Option<String>`
   - Tun fd on Android: `Args::tun_fd: Option<i32>` with `close_fd_on_drop: Some(bool)`
   - Traffic counters: `tun2proxy_set_traffic_status_callback`
   - DNS modes: `ArgDns::Direct`, `ArgDns::Virtual`, `ArgDns::OverTcp`
   - Shutdown: `CancellationToken` passed to `general_run_async`

3. **Android Foreground Service Type for VpnService**:
   - On Android 14+ (API 34+), `VpnService` is a system VPN provider. In manifest: `android:foregroundServiceType="specialUse"` or `systemExempted`, with `android.permission.FOREGROUND_SERVICE` and `android.permission.FOREGROUND_SERVICE_SPECIAL_USE`.

---

## 6. Aether Supply Strategy Decision (T0.12)

- Default for Linux x86_64 and arm64: Official release binaries pinned in `third_party/aether.lock` downloaded via `tools/fetch-aether.sh`.
- Windows: Patched binary with `0001-windows-bind-interface.patch` built in CI workflow, with Plan B edge bypass fallback.
- Android: Binary packaged as `libaether.so` into `jniLibs/`.
