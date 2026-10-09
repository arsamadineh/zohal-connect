# ZOHAL CONNECT: MASTER BUILD SPECIFICATION

Spec version 1.0, written 2026-10-08. Audience: an autonomous coding agent (Antigravity or equivalent).
Language of this file: English. Language of the product: Persian only (RTL).
Upstream pinned at write time: CluvexStudio/Aether release v2.3.0 (published 2026-10-04). Re-resolve the latest release tag when you start (section 3.2).

---

## 0. NOTE FOR THE HUMAN (delete before pasting if you want)

1. Paste this whole file as the first message in Planning mode, with an EMPTY workspace. Also save it as `ZOHAL_SPEC.md` in the workspace root.
2. Use the strongest model available. Allow terminal commands and internet access.
3. If the agent stops or the context resets, send exactly: `Resume: follow section 2.6 of ZOHAL_SPEC.md`.
4. No agent can hold your phone or your Windows PC. At the end the agent produces `docs/QA_MANUAL.md`. You run it on real devices. Anything the agent could not verify is listed honestly in its final report.
5. Zohal is a derivative of AGPL-3.0 software. Publish your source if you distribute binaries. Aether's trademark policy requires a different name for derivatives, which "Zohal" satisfies. This is not legal advice.

---

## 1. MISSION

Build **Zohal Connect** (Persian: **قندشکن زحل**; short Persian: **زحل**), a cross-platform censorship-circumvention client for **Windows, Linux and Android**, built on the open-source **Aether** core (Rust, Cloudflare WARP over MASQUE/WireGuard).

Aether alone gives a local SOCKS5 proxy and an interactive terminal. Zohal turns it into a real product:

- System-wide tunneling (TUN) and a system-proxy mode, with no conflicts with other software.
- Connection that starts fast (target: under 2 seconds with a warm cache, under 8 seconds cold) and never hangs for a minute.
- An interface that is minimal, sharp-cornered, Persian-only, RTL, Apple-grade in motion, and structured like Windscribe's interaction model.
- Crash-safe, spam-click-safe, reversible system changes.

Names:
- OS-level name (package, executable, window title, installer, service, notification channel id): **Zohal**
- Name shown inside the interface: **زحل**
- Full descriptive name (About screen, installer subtitle, store text): **Zohal Connect | قندشکن زحل**
- Android applicationId: `app.zohal.connect`. Repo name: `zohal-connect`.

Do NOT use the name "Aether" in any user-visible place except the About screen credit line (Persian text: "بر پایه Aether"). Do NOT copy Windscribe's logo, colors, icons, copy or assets. Copy only interaction patterns (big primary control, two-row bottom selector, compact preferences).

---

## 2. OPERATING PROTOCOL (HOW YOU MUST WORK)

You are building a networking product that changes system routes and DNS. Sloppiness here breaks people's internet. Obey these rules.

### 2.1 Hard rules

R1. **No placeholders, no mock data, no TODO, no "implement later", no stubbed functions, no fake dashboards.** Every number on screen comes from a real source. Every button does something real. If a feature cannot be completed, do not render it; record it in `docs/KNOWN_LIMITS.md`.
R2. **Never invent APIs, flags, crate functions, package names or versions.** If you have not seen it in real docs or source in this session, verify it (read the source, run `--help`, run `cargo doc`, read the package page). Items marked `[VERIFY]` in this spec are exactly the ones you must confirm and record in `docs/AETHER_NOTES.md` or `docs/DECISIONS.md`.
R3. **Never claim something works unless you ran it.** For every gate in section 17, run the command, then paste the command and a short result into `docs/GATES.md`. A gate you could not run is marked `NOT RUN: reason`, never "passed".
R4. **Do not ask me questions.** This spec contains defaults for every decision. If something is truly undecidable, pick the safer option, write one entry in `docs/DECISIONS.md`, and continue.
R5. **Three-attempt rule.** If the same error persists after 3 distinct fix attempts, stop, write `docs/BLOCKERS.md` (exact error, what you tried), apply the fallback named in this spec, and continue. Never loop forever. Never fake success.
R6. **Do not change scope.** Do not add features not in this spec. Do not remove features in this spec. Do not add dependencies outside section 5 without a `docs/DECISIONS.md` entry that justifies it.
R7. **Small verified steps.** After each task: build, test, commit (`git commit` with a message `phase-N: task`). Never leave the repo unbuildable at the end of a task.
R8. **Zero warnings policy.** `cargo clippy --all-targets -- -D warnings`, `cargo fmt --check`, `flutter analyze` (zero issues), `dart format --set-exit-if-changed .` must pass before every phase gate.
R9. **Every system change is journaled before it is applied and undone idempotently** (section 7.8). Never modify a route, DNS setting, proxy setting or firewall rule without a journal entry written first.
R10. **Never touch what Zohal did not create.** Never delete or modify foreign routes, rules, adapters, firewall rules or processes.
R11. **No telemetry, no analytics, no update pings, no crash upload.** The only network traffic is Cloudflare edge traffic via Aether, the Cloudflare registration API via Aether, and the health probe in section 7.6.
R12. **Latest versions, pinned exactly.** At build time resolve the latest stable of every tool and dependency, then pin exact versions in lockfiles. Prefer releases at least 14 days old unless a newer one fixes a security issue. Record every pin with the date in `docs/DEPENDENCIES.md`.
R13. **Do not rewrite working code to "improve" it** after its gate passed, except to fix a bug found later.
R14. **Persian only in the UI.** No English strings in the interface except proper nouns (protocol names listed in section 14.2) and values (IPs, country codes, versions).
R15. **Persian digits in the UI** (section 14.5). Latin digits only in logs, clipboard copies, file names and code.
R16. **No em dashes and no en dashes in any user-visible copy** (Persian or other). Use the Persian comma "،", the semicolon "؛", a colon, or restructure.
R17. **No emoji anywhere** (UI, logs, docs, commit messages).
R18. **Sharp corners only.** Border radius 0 everywhere in app UI (section 12.2).

### 2.2 Failure patterns to avoid (you are known to do these)

- Writing a plausible-looking function that is never called.
- Writing tests that assert nothing, or mocking the very thing under test.
- Saying "this should work" instead of running it.
- Using a flag from memory of a different tool.
- Silently dropping a platform when its build is hard.
- Hard-coding Latin digits or LTR layout "for now".
- Using `localhost` timing assumptions in tests that make them flaky.
- Putting business logic in widgets.
- Leaving `print`, `debugPrint`, `println!` debugging in release code. Use `tracing` (Rust) and a tiny logger (Dart) routed to the in-app log.

### 2.3 Before writing any code (mandatory, in this order)

1. Create the workspace layout from section 6.2.
2. Install the Taste Skill guidance: run `npx skills add Leonxlnx/taste-skill --skill design-taste-frontend`, and also add `output-skill` and `minimalist-skill` from the same repo (`npx skills add Leonxlnx/taste-skill`). Read their `SKILL.md` files. They are web-oriented (React, Tailwind, GSAP). Our UI is Flutter. Apply their PRINCIPLES (brief inference, the three locks, the ban list, the dark-mode protocol, the pre-flight check, anti-laziness). Do NOT copy web code. Where they conflict with this spec, this spec wins.
3. Create `AGENTS.md` at the repo root: a condensed copy of section 2 (at most 80 lines) so every future session loads the rules automatically.
4. Create `docs/PROGRESS.md`: a checklist of every task in section 17, all unchecked.

### 2.4 Sandbox honesty

You can probably build and test on Linux only. For Windows and Android:
- Write all code and CI workflows so GitHub Actions (`windows-latest`, `ubuntu-latest`, Android emulator) builds and runs what it can.
- Mark each Windows/Android behavior you cannot execute as `NOT RUN` in `docs/GATES.md` and add the exact manual steps to `docs/QA_MANUAL.md`.

### 2.5 Output hygiene

Final repository must contain no generated junk, no committed build outputs, no secrets, no leftover experiment code outside `tools/experiments/` (keep experiments there, documented).

### 2.6 Resume protocol (use at the start of EVERY session)

1. Read `AGENTS.md`, `ZOHAL_SPEC.md`, `docs/PROGRESS.md`, `docs/DECISIONS.md`, `docs/BLOCKERS.md`.
2. Run the build and tests to learn the true state.
3. Continue with the first unchecked task in `docs/PROGRESS.md`. Do not restart finished work.
4. Update `docs/PROGRESS.md` after every task.

---

## 3. UPSTREAM STUDY: AETHER (what is known, what you must verify)

### 3.1 Facts gathered from upstream docs and releases (as of 2026-10-08)

Source: https://github.com/CluvexStudio/Aether (README, Docs/DOCS.en.md, release notes v1.5.0 and v2.3.0, TRADEMARK.md).

- Aether is a **user-space proxy client for Cloudflare WARP** written in Rust. It needs no root and installs no driver. It runs the tunnel, a user-space TCP/IP stack and the proxy inside one process.
- Default SOCKS5 listener: `127.0.0.1:1819` (an older guide file says 10808; the older guide is stale). HTTP CONNECT listener: `--http-proxy <addr>` (env `AETHER_HTTP_PROXY`). **Neither proxy has authentication.**
- Transports: MASQUE (default; HTTP/3 over QUIC on UDP, or HTTP/2 over TCP with `--h2`), WireGuard (`--wg`, alias `--warp`), and "gool" nested modes. WARNING: release v2.3.0 notes say `--gool` now carries a WireGuard WARP identity inside the MASQUE tunnel and the classic WireGuard-in-WireGuard mode is `--gool-classic`, while the docs on `main` describe `--gool` as classic and mention `--mim` (MASQUE-in-MASQUE). **Docs on `main` can describe unreleased behavior.** Always read docs and `--help` at the pinned release tag.
- Endpoint discovery: scan modes `turbo`, `balanced` (default), `thorough`, `stealth`, `ironclad`. A candidate must pass an end-to-end data-plane check before the proxy port opens. `--quick-reconnect` reuses the saved endpoint; v2.3.0 remembers the last eight working gateways; a failed endpoint is held on a cooldown. `--peer <ip:port>` skips the scan.
- Obfuscation: `--noize off|light|balanced|aggressive` (WireGuard family) and, per v2.3.0 notes, `firewall` and `gfw` for MASQUE (the default MASQUE profile is `firewall`; these were not implemented before v2.3.0). QUIC v2 opener is on by default (`--no-quic-v2` disables). `--fragment` (HTTP/2 ClientHello fragmenting), `--ech auto`.
- Routing rules: `--route-block`, `--route-direct`, `--routes <file>`. Entry syntax: `example.com` (name and subdomains), `full:`, `keyword:`, `regexp:`, CIDR or bare IP, `port:N` or `port:A-B`, `private`. Block is checked first, then direct, else tunnel. Behind a TUN front end, names are recovered by sniffing the TLS server name or HTTP Host from the first bytes (`AETHER_ROUTE_SNIFF`, default on, waits `AETHER_ROUTE_SNIFF_MS`=400). UDP/QUIC flows have no name, so only IP and port rules apply to them. **Per-application rules are intentionally NOT in the core**; they belong in the Android VpnService.
- `--upstream <proxy>` dials out through another proxy.
- `--mark <n>` sets `SO_MARK` on every socket Aether opens (tunnel, scan, upstream, route-direct). Linux and Android only. Needs root or CAP_NET_ADMIN. Registration calls got the mark only from v2.3.0.
- `--dns <list>` sets resolvers used inside the tunnel. `--stats` logs byte counters and uptime. `--exit-loc '!IR,AZ'` or `--exit-loc DE,SE` accepts/refuses exit countries (checked at start and every minute).
- Identity files are written next to the config path: `aether.toml` (WireGuard), `aether-masque.toml` (MASQUE), `aether-*-lastconn.toml` (last working endpoint). Deleting identity registers a new device. The file holds private keys. If Cloudflare stops accepting a saved identity, Aether re-registers it (disable with `AETHER_REPROVISION=0`).
- Env/flags: every flag has an `AETHER_*` variable; flags win. `AETHER_PERF_PROFILE=low|medium|high`, `AETHER_LOG_LEVEL`, `AETHER_MAX_CLIENTS`, `AETHER_MASQUE_STARTUP_SECS`, `AETHER_MASQUE_RECONNECT_SECS`, `AETHER_WG_RECONNECT_SECS`, and others.
- Running with no flags makes Aether ASK QUESTIONS interactively. **Zohal must always pass every needed flag and close stdin so Aether can never block on a prompt.**
- Library mode exists: the crate also builds `libaether.a/.so` with a handle-based, polled C API (`aether_core_start`, `aether_job_poll`, `aether_job_cancel`, `aether_string_free`, replies as JSON). The data path is channel-based with no tun code. Header location is `[VERIFY]` (upstream docs say `ios/Shared/aether.h` in the Oblivion client).
- Build: Rust (latest stable; **v2.3.0 requires Rust 1.98**), C/C++ compiler, CMake. `quiche` (Cloudflare) is vendored beside `aether/` in the repo. Release assets (27) include: linux x86_64/arm64/armv7 (+ musl variants), macOS, windows x86_64, android (Termux-targeted) arm64/armv7/x86_64, each with `.sha256`, plus `SHA256SUMS.txt`. Windows zip includes `run-aether.bat` (do NOT ship it). Tor and Psiphon helper binaries ship in a `pt/` folder (out of scope).
- License: **AGPL-3.0**. Trademark: derivatives must use a different name and branding (TRADEMARK.md).

### 3.2 Phase 0 tasks (do these FIRST; write results into `docs/AETHER_NOTES.md`)

T0.1 Resolve the latest release: `curl -s https://api.github.com/repos/CluvexStudio/Aether/releases/latest`. Record tag, commit and asset checksums in `third_party/aether.lock`. Clone with submodules/vendored quiche at that TAG (not `main`) into `third_party/aether-src/`. Read `Docs/DOCS.en.md`, `Docs/DOCS.fa.md`, `README.md` at that tag using `git show <tag>:<path>`.
T0.2 Obtain the binary: for Linux x86_64 download the official release asset and verify SHA256. Run `aether --version` and `aether --help` and save full help output into `docs/AETHER_NOTES.md`.
T0.3 Fill the flag mapping table (Appendix A) from the REAL `--help`. Fix any flag names that differ. The mapping table in the repo must match reality, not this spec.
T0.4 Experiment E1 (no prompts): run Aether with the full flag set from Appendix A, stdin closed, in a subprocess harness. Confirm it never blocks on a prompt. Capture the exact log lines for: starting scan, candidate found, data-plane validated, listening, tunnel lost, reconnect, identity replaced, registration failure. Save samples in `tools/experiments/aether-logs/`.
T0.5 Experiment E2 (readiness): confirm the SOCKS port opens only AFTER the data-plane check. Measure time to port-open for: cold (no lastconn), warm (`--quick-reconnect`), `--scan turbo`, MASQUE h3, MASQUE h2, WireGuard. Ten runs each. Record p50 and p95.
T0.6 Experiment E3 (concurrency): start two Aether processes at once with separate ports and separate COPIES of the identity files (one for MASQUE h3, one for MASQUE h2). Confirm both reach ready and keep working simultaneously (trace through both). Result decides the fast-connect strategy in section 7.5 (race or hedged-sequential).
T0.7 Experiment E4 (data check): `curl -x socks5h://127.0.0.1:<port> https://1.1.1.1/cdn-cgi/trace` returns `warp=on`. Confirm the IP-literal URL works (no DNS needed). Save sample.
T0.8 Experiment E5 (TUN front end): build `tun2proxy` (crates.io, latest) in a Linux network namespace test (`tools/experiments/netns/`): tun device, route into it, SOCKS upstream = Aether, test TCP, UDP (DNS to 1.1.1.1), QUIC-sized datagrams (1250 bytes), IPv6, and measure throughput with a local dummy SOCKS5 upstream. Pass: TCP and UDP work, no packets bypass, throughput at least 200 Mbit/s on loopback dummy upstream. If tun2proxy fails these, fallback front end is `hev-socks5-tunnel` (C, MIT) behind the same `TunFrontend` trait. Record the tun2proxy public API you will use: `[VERIFY]` (run mode with fd on Android, tun name on desktop, traffic counters callback, UDP associate, DNS handling, shutdown).
T0.9 Experiment E6 (loop prevention on Linux): with the policy-routing design in section 8.1, prove Aether's own sockets (marked) bypass the TUN and unmarked sockets go through it. Use `ip rule`, `ss`, and a packet capture on the physical interface.
T0.10 Experiment E7 (Windows bind): grep the Aether source for where `--mark` / `SO_MARK` is applied (a central socket factory). Decide whether adding a Windows branch that sets `IP_UNICAST_IF`/`IPV6_UNICAST_IF` to the physical interface index is feasible as a small patch. If yes, write `patches/0001-windows-bind-interface.patch` (new env `ZOHAL_BIND_IFINDEX`), build patched Aether on `windows-latest` in CI. If not feasible after 3 attempts, use the Windows fallback in section 8.2 (Plan B) and document it.
T0.11 Experiment E8 (Android exec): on the CI emulator (API 34), verify an Aether binary named `libaether.so` placed in `jniLibs/<abi>/` with `extractNativeLibs=true` and `useLegacyPackaging=true` executes from `nativeLibraryDir` and prints `--version`. Preferred build: from source with `cargo-ndk` using NDK r28 or newer (16 KB page alignment). Fallback: the official Android (Termux-targeted) release binary, verified to run, with the 16 KB alignment limitation recorded in `docs/KNOWN_LIMITS.md`. Also verify TLS root certificates work on Android (set `SSL_CERT_FILE` to a bundled `cacert.pem` if needed).
T0.12 Decide the Aether supply strategy and record it: DEFAULT is to download the official release binaries (pinned tag + checksum) for each platform via `tools/fetch-aether.*`. Build from source only for the Windows patch (T0.10) and Android (T0.11).

Phase 0 gate: `docs/AETHER_NOTES.md` has the real help output, the final flag table, results of E1 to E8 with numbers, and every `[VERIFY]` item in this spec resolved or explicitly marked `UNRESOLVED` with its fallback.

---

## 4. PRODUCT DEFINITION

### 4.1 Platforms and tiers
- Windows 10 (build 19041 or newer) and 11, x86_64. Installer `.exe`.
- Linux x86_64 and arm64, systemd-based distributions. `.deb`, `.rpm` and a `.tar.gz` with an install script.
- Android 8.0+ (API 26+), arm64-v8a, armeabi-v7a, x86_64. Signed APKs (per ABI).
- Not in scope: macOS, iOS, Tor, Psiphon, Zero Trust, a built-in updater, accounts, server lists, locations. (Cloudflare chooses the exit.) Leave no UI for these.

### 4.2 Core user stories (all must work)
1. Install, onboard in under 30 seconds, first connection verified.
2. One tap connects. One tap disconnects. Spamming the control never breaks state.
3. Connect during a bad network: automatic fallback across methods without user action.
4. Switch Wi-Fi to mobile data or sleep/wake: the tunnel recovers by itself.
5. Domestic (.ir) sites and LAN stay direct by default (smart routing).
6. Choose system-wide (TUN) or system proxy on desktop.
7. If the app or service crashes, the user's internet and settings are restored automatically.

---

## 5. TECH STACK (decisions are final; resolve latest stable versions at build time and pin)

| Layer | Choice | Reason |
|---|---|---|
| UI | **Flutter** (latest stable) + Dart 3, Material 3 as a base only, fully re-themed | One renderer on all three platforms gives identical motion and RTL/Persian shaping. Proven precedent for VPN-style apps: FlClash, Hiddify. |
| UI state | `flutter_riverpod` | Fine-grained rebuilds, no codegen needed. |
| Rust to Dart | `flutter_rust_bridge` v2 with cargokit | Typed API, streams, builds Rust inside `flutter build` for Windows, Linux, Android. |
| Engine | **Rust** (latest stable, must be at least what Aether needs, 1.98 for v2.3.0), `tokio` (minimal features), `tokio-util`, `serde`, `thiserror`, `tracing` | Same language as Aether; one toolchain. |
| IPC | `interprocess` crate (local sockets: Windows named pipe, Unix domain socket, Android abstract socket) with newline-delimited JSON, versioned | One protocol on every platform. |
| TUN front end | `tun2proxy` (Rust, MIT) as primary; `hev-socks5-tunnel` as fallback behind a `TunFrontend` trait | Pure Rust, no C toolchain for the main path. Verify in E5. |
| Windows TUN driver | Wintun (`wintun.dll`, verify checksum and license for redistribution) | Standard, signed. |
| Windows APIs | `windows` crate (IP Helper, Service Control, registry, WinInet) | No parsing of localized CLI output. |
| Windows service | `windows-service` crate | Native service. |
| Linux system calls | `ip` (iproute2) invoked with fixed argument arrays (never a shell), `resolvectl`, `nft` not used; `zbus` for D-Bus (logind sleep events, accent color) | Predictable, universal. |
| Linux service | systemd unit with `Type=notify` (`sd-notify`) and watchdog | Restart on failure. |
| Android native | Kotlin, `VpnService` in a separate process `:vpn`, JNI into the Rust engine, `cargo-ndk` | Standard split, crash isolation. |
| Desktop shell | `window_manager`, `tray_manager` (tray is optional, degrade silently if unavailable) | Window position memory, tray. |
| Theming | `dynamic_color` on Android only; desktop accent read via the Rust bridge (Windows `UISettings`/registry, Linux XDG portal `accent-color` over D-Bus) | System-based coloring. |
| Font | **Vazirmatn** variable (OFL license), subset (section 15.3) | Required. |
| Icons | Flutter built-in `Icons.*_sharp` (tree-shaken), plus one custom painter for the brand mark and connect control | Sharp style, zero extra weight. |
| Storage | Atomic JSON files (write temp, fsync, rename) with a `.bak` and a schema version | No database needed. |
| Windows installer | **Inno Setup 6** with Persian RTL wizard | Free, UAC prompt at install, service registration. |
| Linux packaging | **nfpm** (one YAML to `.deb` and `.rpm`) | One config, two formats. |
| CI | GitHub Actions | Builds all three, runs tests. |
| Supply chain | `Cargo.lock`, `pubspec.lock` committed; `cargo deny` and `cargo audit` in CI | Reproducible, audited. |

Allowed Dart packages (nothing else without a DECISIONS entry): `flutter_riverpod`, `flutter_rust_bridge`, `window_manager`, `tray_manager`, `dynamic_color`, `path_provider`, `package_info_plus`, `url_launcher`, `flutter_localizations` (SDK), `intl` only if needed by SDK localization.

Allowed Rust crates (beyond std): `tokio`, `tokio-util`, `serde`, `serde_json`, `thiserror`, `tracing`, `tracing-subscriber`, `interprocess`, `tun2proxy`, `windows`, `windows-service`, `zbus`, `sd-notify`, `jni`, `libc`, `nix`, `flutter_rust_bridge`, `rustls` or `ureq` (health probe only, smallest option), `sha2`, `parking_lot`. Anything else needs a DECISIONS entry.

---

## 6. ARCHITECTURE

### 6.1 Component diagram

```
                      ┌──────────────────────────────────────────────┐
                      │  Flutter UI (Dart)  : unprivileged, per user │
                      │  screens, state (Riverpod), design system    │
                      └──────────────┬───────────────────────────────┘
                                     │ flutter_rust_bridge (typed)
                      ┌──────────────▼───────────────────────────────┐
                      │  zohal-bridge (Rust cdylib in UI process)    │
                      │  IPC client; Android: JNI/platform glue      │
                      └──────────────┬───────────────────────────────┘
                 local socket (JSON lines, versioned, peer-checked)
        ┌────────────────────────────┴─────────────────────────────┐
        │ DESKTOP                                      ANDROID     │
        │ zohald service (TUN scope)     :vpn process (VpnService) │
        │ zohald user    (proxy scope)   hosts the same engine     │
        └────────────────────────────┬─────────────────────────────┘
                      ┌──────────────▼───────────────────────────────┐
                      │ zohal-engine (Rust crate): reconcile loop,   │
                      │ ladder, cache, health, journal, routing      │
                      └───────┬─────────────────────┬────────────────┘
                              │ spawns (child)      │ in-process
                   ┌──────────▼─────────┐   ┌───────▼────────────────┐
                   │ aether (pinned)    │◄──┤ tun2proxy (TUN front)  │
                   │ SOCKS5 127.0.0.1:P │   │ packets <-> SOCKS5     │
                   └──────────┬─────────┘   └───────▲────────────────┘
                              │ Cloudflare edge      │ TUN device
                              ▼                      │ (Wintun / zohal0 / VpnService fd)
```

Why a separate engine process on desktop: privilege separation (UI never runs as admin), UI crashes never drop the tunnel, the tunnel survives closing the window, and the engine can clean up after itself.

### 6.2 Repository layout (create exactly this)

```
zohal-connect/
  AGENTS.md  ZOHAL_SPEC.md  README.md  LICENSE(AGPL-3.0)  NOTICE.md
  THIRD_PARTY_LICENSES/            (aether, quiche, tun2proxy, wintun, vazirmatn, flutter, each full text)
  third_party/aether.lock          (tag, commit, per-asset sha256)
  third_party/aether-src/          (only if a source build is needed)
  patches/                         (0001-windows-bind-interface.patch if feasible)
  tools/ fetch-aether.sh fetch-aether.ps1 subset-font.sh gen-icons.* experiments/
  docs/ ARCHITECTURE.md DECISIONS.md GATES.md PROGRESS.md BLOCKERS.md KNOWN_LIMITS.md
        QA_MANUAL.md AETHER_NOTES.md DEPENDENCIES.md STRINGS_FA.md
  engine/                          (Cargo workspace, rust-toolchain.toml pinned)
    crates/
      zohal-proto/     types, IPC messages, settings schema, error codes, constants
      zohal-engine/    reconcile loop, ladder, cache, health, journal, routing compiler, aether supervisor
      zohal-platform/  trait Platform; windows.rs linux.rs android.rs proxy_only.rs
      zohal-tun/       TunFrontend trait; tun2proxy impl; counters
      zohald/          bin: `service`, `user`, `install`, `uninstall`, `cleanup`, `status`
      zohal-bridge/    FRB crate: IPC client, theme/accent, autostart; Android JNI exports
    tests/             fake-aether harness, state-machine property tests, netns e2e scripts
  app/                             (Flutter)
    pubspec.yaml  analysis_options.yaml
    lib/
      main.dart  app.dart
      core/        bridge.dart engine_state.dart settings.dart logger.dart persian.dart
      design/      tokens.dart theme.dart motion.dart components/ (button, row, toggle, sheet, toast, field, dialog)
      features/    connect/ mode/ routing/ settings/ logs/ about/ onboarding/
      l10n/        strings_fa.dart
    assets/fonts/Vazirmatn/  assets/licenses/
    android/ (Kotlin: MainActivity, ZohalVpnService, ZohalTileService, BootReceiver, Notifications)
    windows/  linux/
    test/ (unit, widget, golden)  integration_test/
  packaging/
    windows/zohal.iss  linux/nfpm.yaml  linux/zohald.service  linux/zohal.desktop
    android/ signing.md
  .github/workflows/ ci.yml  release.yml
```

### 6.3 Engine hosts
- `zohald service` (TUN scope): Windows service `ZohalEngine` (LocalSystem, auto start, restart on failure) and Linux systemd unit `zohald.service` (hardened, section 8.1). Needed for TUN. Owns Aether child, TUN, routes, DNS.
- `zohald user` (system-proxy scope, desktop only): unprivileged, per user, detached from the UI so closing the window does not drop the proxy. Owns Aether child and the user's system proxy setting. It exits when the connection is closed.
- Only one engine host may be connected at a time. Enforce with a machine-wide lock (Windows named mutex `Global\ZohalActive`, Linux `flock` on `/run/zohal/active.lock` for service and a user-level check). A second connect returns error `E300` (busy).
- Android: the engine runs inside `ZohalVpnService` (process `:vpn`).

### 6.4 IPC protocol (version 1, newline-delimited JSON)

Handshake: client sends `{"t":"hello","proto":1,"client":"<ver>"}`; server replies `{"t":"hello","proto":1,"server":"<ver>","caps":[...]}`. A mismatched `proto` returns `E250` and closes.

Client commands: `set_desired{up:bool, epoch:u64}`, `get_state`, `subscribe{stats:bool}`, `unsubscribe`, `get_settings`, `patch_settings{...partial...}`, `probe_now`, `export_diagnostics`, `reset_identity`, `ping`.
Server messages: `state{...}`, `stats{rx_bps,tx_bps,rx_total,tx_total}` (max 1 Hz, only while subscribed), `log{ts,level,code?,msg}`, `notice{code,params}`, `error{code,...}`.
The UI can never ask the engine to run a command, open a path, or load a file. Only the enumerated typed commands above exist.

Peer authentication: Windows pipe DACL grants SYSTEM and Administrators full control and Authenticated Users read/write. Linux socket `/run/zohal/engine.sock` mode 0666 with a `SO_PEERCRED` check: allow root or any uid with an active logind session. Android abstract socket checks `SO_PEERCRED` uid equals own uid.

### 6.5 State object (what the UI renders)

```
phase: Idle | Preparing | Connecting | Connected | Reconnecting | Disconnecting | Failed
stage: Prepare | FindGateway | BuildTunnel | VerifyPath | None
desired: up|down   epoch: u64
transport: Masque3 | Masque2 | WireGuard | GoolMasque | GoolClassic | None
rung: u8   attempt: u32   gateway: Option<String>
exit_ip: Option<String>   exit_loc: Option<String>   colo: Option<String>
since_unix: Option<i64>
error: Option<ErrorCode>  fail_streak: u32
scope: Tun | SystemProxy   kill_switch_engaged: bool
```

---

## 7. ENGINE BEHAVIOR

### 7.1 Reconcile loop (the heart; this design is what makes spam-clicking safe)

The engine is LEVEL-TRIGGERED, not command-triggered.
- UI writes `desired` (up or down) and `epoch` into a `tokio::sync::watch` channel. A watch channel keeps ONLY the latest value, so 100 rapid toggles collapse to the final intent automatically.
- One single task, the `Supervisor`, owns all state and all side effects. No other task mutates system state.
- Loop: wait until `desired` differs from reality, then run ONE transition (`bring_up` or `tear_down`) as a future raced against `desired_rx.changed()`. If the intent changes mid-transition, cancel the transition cooperatively at the next checkpoint, run its cleanup, then re-evaluate.
- **Settle window:** before beginning a heavy `bring_up`, wait 120 ms for `desired` to stay stable. Connect, disconnect, connect within 120 ms becomes a single connect (or nothing).
- `tear_down` is never interrupted; it is fast (target 300 ms, hard cap 3 s) and idempotent. After it finishes the loop re-reads `desired`.
- Cleanup of a cancelled transition uses the undo stack (section 7.8), executed explicitly (not in `Drop`).
- Invariants (assert in tests): at most 2 Aether child processes exist at any time and only during the race window; at most one TUN device; routes/DNS/proxy changes exist only when `phase` is Connected, Reconnecting or in the middle of a transition; after `tear_down` completes there are zero Zohal-created system changes.

### 7.2 Phases and allowed transitions

```
Idle ──up──► Preparing ──► Connecting ──► Connected
  ▲             │              │             │  tunnel lost
  │             ▼              ▼             ▼
  └──────── Disconnecting ◄────┴──── Reconnecting ──► Connected
                 ▲                         │ ladder exhausted
Failed ◄─────────┴─────────────────────────┘ (from Connecting or Reconnecting)
Failed ──up──► Preparing        Failed ──down──► Idle
```
Any phase may go to Disconnecting when `desired=down`. Disconnecting always ends in Idle.

### 7.3 Connect pipeline (`bring_up`) with stage reporting

1. **Prepare (stage Prepare), budget 150 ms:** engine alive; settings valid; journal clean (else run cleanup first); pick free ports (section 8.4); pick TUN subnet and rule numbers by probing existing system state; read the physical default route (interface, gateway); detect other VPN adapters (log a notice, proceed).
2. **Find gateway (stage FindGateway):** start the Aether candidate(s) per the ladder (7.5). Wait for the SOCKS port to accept connections (Aether opens it only after its own data-plane validation, verify in E2). Per-rung deadlines apply.
3. **Build tunnel (stage BuildTunnel):** start TUN front end, apply routes, DNS, system integration (platform spec). Each step registers its undo in the journal BEFORE applying.
4. **Verify path (stage VerifyPath):** request `https://1.1.1.1/cdn-cgi/trace` THROUGH the new path (section 7.6). Require `warp=on` (or `warp=plus`). Parse `ip`, `loc`, `colo`. On failure: undo steps 3, stop candidate, go to the next rung. Do not report Connected until this passes.
5. Publish `Connected`, start health monitor and background gateway warming (7.6, 7.7).

### 7.4 Time budget (targets, measured and reported in `docs/GATES.md`)

- UI feedback within one frame (optimistic, section 12.6).
- Engine acknowledges `set_desired` within 50 ms.
- Warm connect (cached gateway, same network): p50 under 2 s. Cold: under 8 s typical. These are TARGETS; report real measured numbers honestly.
- Disconnect: under 300 ms typical, 3 s hard cap with forced kill escalation.

### 7.5 Fast connect strategy and the Auto ladder

Why other clients take a minute: they scan serially with long timeouts and register the device on first connect. Zohal avoids this with these techniques, all required:
1. **Register during onboarding**, not at first connect. Identity files exist before the first real connect.
2. **Endpoint cache** (7.7) so no scan is needed on a known network.
3. **Rung memory:** remember which rung won per network fingerprint (TTL 7 days, decays on failure) and start there.
4. **Parallel racing:** run rung 1 (h3) and rung 2 (h2) at the same time if E3 passed (separate ports, separate identity copies); first to pass the data check wins; kill the loser within 200 ms. If E3 failed, use hedged-sequential: start rung 2 after 1.5 s without killing rung 1.
5. **Strict per-rung deadlines** (below), never one long timeout.
6. **Gateway warming** while connected, so the next reconnect is instant.

Ladder for connection mode `Auto` (deadlines are per rung; total cap 35 s then Failed with `E120`):

| Rung | Transport | Scan | Noise | Gateway source | Deadline |
|---|---|---|---|---|---|
| 1 | MASQUE h3 | turbo + quick-reconnect | firewall | cache | 4 s |
| 2 | MASQUE h2 (raced/hedged with 1) | turbo + quick-reconnect | firewall | cache (h2-proven) | 5 s |
| 3 | MASQUE h3 | balanced | gfw | fresh scan | 8 s |
| 4 | MASQUE h2 with fragment | balanced | gfw | fresh scan | 8 s |
| 5 | WireGuard | balanced | balanced then aggressive | fresh scan | 8 s |
| 6 | gool (v2.3.0 MASQUE-carried; then gool-classic) | thorough | aggressive | fresh scan | 12 s |

If the user picks a specific method, run ONLY that method with the same deadlines, escalating only its noise profile and scan mode (never silently switching transport), and fail with a clear message.
Skip rungs known to be impossible (for example, skip h3 rungs for 20 minutes after UDP-blocked evidence on this network fingerprint).
Clock skew check: if TLS handshakes fail on every rung and the system clock differs from the `Date` header of any TLS/HTTP response by more than 5 minutes, fail with `E110` instead of cycling.

### 7.6 Health monitoring and verification

- **Verification probe:** `GET https://1.1.1.1/cdn-cgi/trace` (IPv6 fallback `https://[2606:4700:4700::1111]/cdn-cgi/trace`). Success when the body contains `warp=on` or `warp=plus`. Implement as a tiny dedicated client with a 3 s timeout. Desktop TUN: unmarked, so it travels through the TUN (true end-to-end). Proxy scope and Android: probe through the Aether SOCKS port (`socks5h`), because the engine process itself is excluded from the tunnel on Android; on Android the UI process additionally runs an opportunistic end-to-end probe through the tunnel when visible. Record this limitation in `docs/KNOWN_LIMITS.md`.
- **Passive first:** monitor byte counters from the TUN front end. Only if bytes go out without bytes coming back for 10 s, run the active probe. No periodic probing on an idle tunnel (saves battery and avoids pointless traffic).
- Two consecutive failed probes within 6 s declare the tunnel lost: `Reconnecting` (TUN stays up, section 9.4).
- **Network change events** (section 8): debounce 800 ms, then probe; reconnect only if the probe fails.
- **Sleep/resume:** after resume wait 1.5 s, probe, then decide.
- **Aether child exit:** unexpected exit triggers `Reconnecting` immediately. Capture the last 50 lines of stdout/stderr for the log.
- **Captive portal:** if the probe returns an HTTP redirect or a non-Cloudflare body on the underlying network, report `E100` with a hint, do not loop.

### 7.7 Cache (the "auto cache")

- `endpoints.json`: per network fingerprint, up to 8 verified gateways per transport (most recent first), each with last RTT, last success time, failure count, cooldown-until. Global fallback list of 16. TTL 24 hours; entries failing twice get a 10 minute cooldown (mirror Aether's behavior); `h3`-proven and `h2`-proven are separate.
- `rungs.json`: winning rung per fingerprint (TTL 7 days).
- Network fingerprint: `sha256(salt | transport_kind | default_gateway_ip)` truncated to 16 hex chars. NEVER store SSID, BSSID, MAC or location. On Android cellular use `transport_kind` only. The salt is random per install.
- Gateway warming: while connected, every 10 minutes (when the device is not in battery saver), probe the top 3 cached gateways with a lightweight validation (no tunnel disruption) and refresh RTT/cooldown. Skip on metered networks on Android.
- All cache files are written atomically and tolerate corruption (corrupt file moves to `.corrupt`, a fresh file starts, no crash).
- Prefer reading Aether's own `lastconn` files only if their format is stable and documented (E4); otherwise keep Zohal's own cache fed by log lines or by the `--peer` that won.

### 7.8 Journal and undo (crash safety)

- Every system change is an `Action { kind, params, undo }`. Before applying an action, append `{id, kind, params, undo}` to `journal.json` (fsync). After undo succeeds, remove it.
- On engine start (service start, user host start, Android service start), if the journal is non-empty, run all undos in reverse order BEFORE accepting commands. Log what was cleaned.
- `zohald cleanup` performs the same cleanup on demand (used by the uninstaller and by a documented rescue command).
- Undo operations are idempotent: removing something that no longer exists is success.
- TUN device and its routes vanish with the process on Linux (non-persistent tun) and Windows (Wintun adapter handle closed). The journal covers the rest: policy rules, DNS settings, firewall rules, proxy settings.
- Child processes: Linux uses `PR_SET_PDEATHSIG` + own process group (and systemd `KillMode=control-group`); Windows puts Aether in a Job Object with `KILL_ON_JOB_CLOSE`; Android spawns through a Rust JNI helper using `PR_SET_PDEATHSIG` and also sweeps stale `aether` processes owned by our uid at service start (verify `/proc/<pid>/cmdline`).

### 7.9 Spam-click torture requirements (must be tested, section 17)

- Property test with the fake-Aether harness: random sequences of 10,000 `set_desired` toggles at random intervals from 0 to 300 ms, with random injected failures. After quiescence assert: final phase matches final desired; zero leaked processes; zero leaked journal entries; zero leaked system changes; no state transition outside the table in 7.2; memory stable.
- The engine must never panic. Panics in child tasks are caught, logged, and converted to `E400` with a restart.


---

## 8. PLATFORM SPECIFICATIONS

### 8.1 Linux (TUN scope, systemd service)

Service: `zohald.service` runs `zohald service` as root with hardening: `NoNewPrivileges=yes`, `ProtectSystem=strict`, `ProtectHome=yes`, `PrivateTmp=yes`, `ReadWritePaths=/var/lib/zohal /run/zohal`, `CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_SETUID CAP_SETGID`, `RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_NETLINK`, `Restart=on-failure`, `Type=notify`, `WatchdogSec=30`, `RuntimeDirectory=zohal`, `StateDirectory=zohal`. Aether child runs as dedicated system user `zohal` with ambient `CAP_NET_ADMIN` only (needed for `--mark`). Create the user in package postinst.

TUN: device `zohal0`, MTU 1280, IPv4 `/30` from the candidate list (section 8.5), IPv6 ULA `/126`. Created by the TUN front end, configured with `ip`.

Policy routing (the wg-quick pattern; this is what prevents loops AND keeps LAN reachable):
```
M = chosen fwmark (probe free value, start at 0x5A48)
T = chosen table id (probe free value)
ip route add default dev zohal0 table T          (and -6)
ip rule add pref P1 fwmark M lookup main         (and -6)   # Aether's own sockets use the real route
ip rule add pref P2 lookup main suppress_prefixlength 0     # LAN and connected routes keep working
ip rule add pref P3 lookup T                                # everything else goes to the tunnel
```
`P1<P2<P3<32766`, chosen by probing unused priorities (avoid the 5210 to 5270 range that Tailscale uses). Aether is started with `--mark M`. All of this is journaled.

DNS: if `systemd-resolved` is active use `resolvectl dns zohal0 <servers>` and `resolvectl domain zohal0 '~.'` (undo: `resolvectl revert zohal0`). Else if NetworkManager manages DNS, use its dispatcher-safe method documented in DECISIONS. Else back up `/etc/resolv.conf` (journaled, restore on undo). Optional split DNS for `.ir` through the physical DNS only when `resolved` is present (`resolvectl domain <phys> '~ir'` is NOT allowed; use per-link domains on the physical link only if you recorded its previous domains in the journal).

IPv6: either tunnel it (route `::/0` into `zohal0` with the same rules) or blackhole it while connected. Never leak.

Network events: netlink (`RTMGRP_LINK|IPV4_ROUTE|IPV6_ROUTE`) or `ip monitor`. Sleep: `zbus` logind `PrepareForSleep`.

System proxy scope (`zohald user`): GNOME `gsettings org.gnome.system.proxy` (mode manual, http/https/socks host and port, ignore-hosts including LAN and `.ir` if smart routing is on); KDE `kwriteconfig6`/`kwriteconfig5` on `kioslaverc` plus `dbus` notify. Save previous values to the user journal and restore on disconnect. Detect desktop from `XDG_CURRENT_DESKTOP`; on an unknown desktop disable the scope with a clear message.

Packaging: `.deb`, `.rpm` via nfpm: installs `/opt/zohal/` (Flutter bundle), `/usr/lib/zohal/zohald`, `/usr/lib/zohal/aether`, unit file, `.desktop`, icons; `postinst` creates user `zohal`, enables and starts the service; `prerm` stops it and runs `zohald cleanup`. Tarball ships `install.sh` using `pkexec`. Non-systemd distributions: unsupported for TUN, document it.

### 8.2 Windows (TUN scope, Windows service)

Service `ZohalEngine` (LocalSystem, automatic start, failure actions: restart after 1 s, 5 s, 30 s). Single user-visible name "Zohal". Binaries in `C:\Program Files\Zohal\` (zohald.exe, aether.exe, wintun.dll, UI). The service handles power events (`SERVICE_CONTROL_POWEREVENT`) and network change (`NotifyIpInterfaceChange`, `NotifyRouteChange2`).

Use IP Helper APIs from the `windows` crate. NEVER parse localized `netsh`/`route` output (Persian Windows localizes it). If a CLI must be used, check only its exit code.

TUN bring-up:
1. Create the Wintun adapter named `Zohal` with a fixed GUID (constant in `zohal-proto`).
2. Assign the IPv4 `/30` and IPv6 `/126` (section 8.5) with `CreateUnicastIpAddressEntry`.
3. Routes: `0.0.0.0/1`, `128.0.0.0/1`, `::/1`, `8000::/1` on the Zohal adapter, metric 1. Existing routes are never modified, so LAN and other VPN routes (more specific) keep winning.
4. Interface metric of the Zohal adapter set low; DNS set with `SetInterfaceDnsSettings` to the tunnel DNS servers.
5. DNS leak guard: a Windows Firewall rule group `ZohalDnsGuard` blocking outbound UDP/TCP port 53 on every interface except the Zohal adapter (add via the firewall COM API or `netsh advfirewall` with exit-code checks). Journaled and removed on disconnect and cleanup. Document that Smart Multi-Homed Name Resolution is covered by this rule.

Loop prevention for Aether's own traffic:
- **Plan A (preferred):** the patched Aether (T0.10) sets `IP_UNICAST_IF`/`IPV6_UNICAST_IF` on all outbound sockets to the physical interface index given by `ZOHAL_BIND_IFINDEX`. Then no bypass routes are needed and `--route-direct` for domains works.
- **Plan B (fallback if the patch fails):** add bypass routes (via the physical gateway, journaled) for the Cloudflare edge ranges Aether scans (derive the list from the Aether source at the pinned tag, never from memory) and for the currently active gateway. In Plan B, domain-based direct rules cannot work in TUN scope on Windows (they would loop). Disable that UI switch with the Persian explanation in 14.6, keep CIDR/port direct rules working through OS-level bypass routes, and record it in `docs/KNOWN_LIMITS.md`. The interface must be honest, never silently broken.

System proxy scope (`zohald user`): set `HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings` (`ProxyEnable`, `ProxyServer`, `ProxyOverride` including `<local>` and `*.ir` when smart routing is on), then call `InternetSetOption(INTERNET_OPTION_SETTINGS_CHANGED)` and `INTERNET_OPTION_REFRESH`. Save the previous `ProxyEnable`, `ProxyServer`, `ProxyOverride`, `AutoConfigURL`, `AutoDetect` values in the user journal; restore on disconnect, crash recovery, and uninstall. Detect third-party tampering while connected (re-read every 30 s only while the proxy scope is active, restore our values once and raise `E300`).

Installer (Inno Setup 6, `PrivilegesRequired=admin`, `RightToLeft` Persian wizard text from section 14.8): installs files, registers and starts the service (`sc` or the service API), creates Start Menu shortcut named "Zohal", optional "run with Windows" (UI autostart via `HKCU` run key, off by default; the SERVICE always starts at boot). Uninstall: stop service, run `zohald.exe cleanup`, remove the Wintun adapter, remove firewall rules, ask whether to delete data (default: keep).
Do not ship `run-aether.bat`. Windows ARM is out of scope (upstream dropped it).

### 8.3 Android (TUN scope only)

Process model: `ZohalVpnService` declared with `android:process=":vpn"`, `android:permission="android.permission.BIND_VPN_SERVICE"`, intent filter `android.net.VpnService`, and meta-data `android.net.VpnService.SUPPORTS_ALWAYS_ON=true`. The engine (Rust, via JNI) lives in `:vpn`. The Flutter UI lives in the main process and talks to the engine over the abstract local socket with the SAME IPC protocol as desktop.

Foreground service: required. Foreground service type for `VpnService` on the targeted API: `[VERIFY]` in current Android docs (declare the correct type and permission in the manifest; test on an API 34+ emulator). Notification channel `zohal_status` (low importance, no sound, no badge), persistent notification: title "زحل", text "متصل است · <duration>" (Persian digits), one action "قطع". Android 13+ POST_NOTIFICATIONS requested during onboarding; if denied, the foreground notification still shows and the app continues.

`VpnService.Builder`: session "Zohal"; IPv4 address `/30` from candidates; IPv6 ULA `/126`; routes `0.0.0.0/0` and `::/0`; DNS servers from settings; MTU 1280; `setBlocking(false)`; `setMetered(false)`; `addDisallowedApplication(<own package>)` (Aether's and the engine's own sockets bypass the tunnel: loops impossible, `--route-direct` works naturally; so `--mark` is not needed on Android); per-app split via `addAllowedApplication`/`addDisallowedApplication` (never both kinds at once); configure intent opens the app. `establish()` returns a descriptor; hand its raw fd (`detachFd()`) to the TUN front end through JNI. Calling `establish()` again must close the previous descriptor first. Implement `onRevoke()` (engine receives `external_stop`, notice `E230`).

Aether on Android: executable named `libaether.so` in `jniLibs/<abi>/`, `android:extractNativeLibs="true"`, Gradle `packaging { jniLibs { useLegacyPackaging = true } }`. Launch from `applicationInfo.nativeLibraryDir`. Environment: `HOME`/config dir inside app-private storage, `SSL_CERT_FILE` if E8 showed it is needed. Native code built with NDK r28+ and 16 KB page alignment (`-Wl,-z,max-page-size=16384`).

Network: `ConnectivityManager.NetworkCallback` for default network changes (debounce 800 ms, then probe) and call `setUnderlyingNetworks` with the active network so Android can show correct connectivity and metered state.

Doze and battery: foreground service plus `START_STICKY`; onboarding step offers the ignore-battery-optimizations request (explain in Persian; skippable). The user's "Always-on VPN" and "Block connections without VPN" system settings must be supported; add a settings row that opens `Settings.ACTION_VPN_SETTINGS`.

Extras: Quick Settings Tile (`TileService`) toggling the same desired state (if consent is not granted, the tile opens the app); an app shortcut "اتصال". Per-app split screen lists launcher-visible apps (use a `<queries>` launcher intent filter, not `QUERY_ALL_PACKAGES`).

Boot: `BOOT_COMPLETED` receiver starts the service only if `auto_connect_on_boot` is enabled AND VPN consent already exists (`VpnService.prepare` returns null); otherwise do nothing.

Build: Gradle Kotlin DSL, latest AGP, `minSdk 26`, `targetSdk` and `compileSdk` = latest stable, R8 and resource shrinking on, ABI splits, release signing config read from environment (never committed). Android 12+ splash: background color only, transparent animated icon (avoids the OS circular mask); the first Flutter frame fades in the brand mark. Adaptive icon: full-bleed square artwork plus a monochrome themed layer.

### 8.4 Ports

Per session, choose a free loopback port for each Aether listener by probing from the range 20000 to 59999 with a random start; test-bind it, release it, pass it to Aether; if Aether reports "address already in use", pick another port and retry silently (up to 5 times). On Windows, also skip ports inside the system's excluded ranges (query `GetExcludedPorts`/the API equivalent, not by parsing `netsh`). Never use fixed ports. Loopback only. No authentication exists on these ports; the random port and loopback binding are the mitigation. Record this limit in `docs/KNOWN_LIMITS.md`.

### 8.5 Address and rule candidates (probe and reserve, never assume)

IPv4 TUN `/30` candidates in order: `198.18.0.0/30`, `198.19.0.0/30`, `100.127.255.0/30`, `10.255.255.0/30`. Choose the first that overlaps no existing interface address or route. IPv6 ULA `/126`: `fd7a:6f68:616c::/126` (fall back to a random `fd..` prefix if overlapping). All values are chosen at connect time and stored in the journal.

### 8.6 Interaction with other software (must-pass behaviors)

- Another VPN adapter or VPN app is active: detect (adapter list; Android: VPN transport present), log a notice, proceed on desktop (more specific routes of other VPNs keep priority); on Android the OS allows only one VPN, so a revoke event is handled gracefully.
- Docker, WSL2, Hyper-V, VirtualBox, libvirt bridges: never touched; LAN-like connected routes stay on their interfaces.
- Existing system proxy owned by another app: snapshot and restore, never leave it modified.
- Unique names (adapter `Zohal`, device `zohal0`, rule group `ZohalDnsGuard`, service `ZohalEngine`) so we only ever remove our own.
- Antivirus or firewall blocking Wintun or the service: detect adapter creation failure and show `E210` with a Persian hint.

---

## 9. FEATURES AND SETTINGS

### 9.1 Settings schema (defaults are final)

| Key | Type | Default | Notes |
|---|---|---|---|
| `connection_mode` | Auto, Masque3, Masque2, WireGuard, Gool | Auto | |
| `ip_version` | Auto, V4, V6, Dual | Auto | Auto = Dual only if a global IPv6 route exists |
| `scan_profile` | Auto, Turbo, Balanced, Thorough, Stealth, Ironclad | Auto | Auto = ladder decides |
| `noize_profile` | Auto, Off, Light, Balanced, Aggressive, Firewall, Gfw | Auto | |
| `scope` | Tun, SystemProxy | Tun (desktop, if service reachable; else SystemProxy), Tun (Android) | |
| `kill_switch` | bool | true | |
| `auto_connect_on_launch` | bool | true after onboarding | |
| `restore_last_state` | bool | true | reconnect if the last session ended connected |
| `auto_connect_on_boot` | bool | false | desktop: service connects before login; Android: boot receiver |
| `start_with_system` | bool | false | UI autostart on desktop |
| `minimize_to_tray` | bool | true (desktop) | |
| `routing.smart_domestic_direct` | bool | true | `.ir` names direct (see 9.3) |
| `routing.lan_direct` | bool | true | `private` direct |
| `routing.direct_rules` | list of Rule | [] | |
| `routing.block_rules` | list of Rule | [] | |
| `routing.app_split` | {mode: All, Only, Except; packages} | All | Android only |
| `dns.servers` | list of IP | 1.1.1.1, 1.0.0.1, 2606:4700:4700::1111, 2606:4700:4700::1001 | validated |
| `advanced.fragment` | bool | false | |
| `advanced.ech` | bool | false | |
| `diagnostic_log` | bool | false | |

Settings are validated on both sides (UI form validation AND engine validation). Invalid patches are rejected with a Persian message; the engine never trusts the UI.

### 9.2 Auto connect, precisely
- Launch: if `auto_connect_on_launch` and the last desired was up (`restore_last_state`), set `desired=up` once the engine is reachable. Never prompt.
- Boot (desktop): the service reads settings at start and, if `auto_connect_on_boot`, connects without the UI.
- Network up after offline: if `desired=up` and phase is Failed because of `E100`, retry automatically when connectivity returns (once per change, with backoff 2 s, 5 s, 15 s, 60 s).
- Never auto-connect after the user explicitly disconnected.

### 9.3 Smart routing
Compile user settings into the real Aether rule syntax (Appendix A). Smart defaults: `private` and the suffix rule `ir` go to `--route-direct`. Rule-type picker in the UI validates input against the grammar in section 3.1 and shows the Persian type names in 14.6. Rules are written to a `routes.conf` in the engine data directory (atomic write) and passed with `--routes`. On desktop TUN, additionally apply OS-level bypass for CIDR and `private` rules where the platform plan requires it (Windows Plan B). Document honestly: name-based rules rely on TLS/HTTP sniffing and do not apply to QUIC/UDP flows.
For `.ir` DNS: when the platform supports per-domain DNS routing (Linux with `resolved`), resolve `.ir` through the physical link's DNS; otherwise `.ir` names resolve through the tunnel and direct routing still works by SNI. State this in the routing screen help text only if the limitation is active.

### 9.4 Kill switch semantics
- Engaged = while `Reconnecting`, the TUN and its routes stay up and the TUN front end rejects traffic when the upstream is down (fail closed). Nothing leaks to the physical network. Default on.
- If the user disables it: after 10 s of failed reconnecting, tear the TUN down so direct internet returns, show notice `E400`-class message "اتصال قطع شد؛ اینترنت مستقیم فعال است".
- If the engine itself crashes, the TUN disappears with the process and the journal restores DNS/rules on restart. Document this in `docs/KNOWN_LIMITS.md` as the limit of the soft kill switch (no firewall-level lock in v1). On Android recommend the system "Block connections without VPN" in a settings row.

### 9.5 Diagnostics
`export_diagnostics` writes a text file the user can save/share: app and Aether versions, OS and architecture, settings (rules replaced by counts), the last 200 state transitions with error codes, the last 500 log lines with IPs and domains masked, cache statistics. It never contains keys, identity files, or visited destinations.

### 9.6 Logging and privacy
In-memory ring buffer of 2,000 events for the log screen. No logs on disk unless `diagnostic_log` is on (then rotate at 2 MB, keep 2 files, masked). Destinations are never logged.


---

## 10. SECURITY REQUIREMENTS

- UI to engine: only the typed commands in 6.4, validated; no path or command strings accepted. Fuzz the JSON parser (cargo-fuzz or proptest) and ensure it cannot panic.
- The engine executes ONLY the Aether binary located in its own install directory, checked against a SHA256 recorded at install time. If the hash differs, refuse to start with `E400` and a clear log.
- Identity files and journal: directory owned by root/service (desktop) or app-private (Android), mode 0700/0600. Never readable by other users.
- No shell invocations with string interpolation. All subprocess calls use argument arrays and absolute paths where possible.
- Input validation for IPs, CIDRs, domains, ports, regexps (Rust `regex` crate not allowed unless you add a DECISIONS entry; validate with Aether's own grammar and length limits; reject rules longer than 255 chars and more than 5,000 rules).
- Supply chain: pinned lockfiles, `cargo deny check`, `cargo audit`, download verification for Aether and Wintun by SHA256.
- Document the threat model in `docs/ARCHITECTURE.md`: local unauthenticated proxy ports, local users able to toggle the tunnel, soft kill switch, no hiding of the fact that Cloudflare sees exit traffic.

---

## 11. FAILURE MATRIX (every row needs a test or a documented manual check)

| Situation | Required behavior |
|---|---|
| No internet at all | `E100`, no ladder cycling; auto-retry when connectivity returns |
| Captive portal | detect by probe body/redirect, `E100` with hint |
| UDP blocked or throttled | h3 rungs fail fast; remember; prefer h2 for 20 min on this fingerprint |
| DPI resets handshakes | escalate noise (firewall to gfw; balanced to aggressive) |
| Wrong system clock | `E110` with exact instruction |
| Cached gateway dead | cooldown it, move on, scan |
| Identity rejected by Cloudflare | Aether re-registers; if it fails, `E130` then `E140` guidance; `reset_identity` available in settings |
| Registration API blocked | `E140`; explain that registration is a one-time step and suggest another network |
| Port already in use | silent retry with a new port (up to 5) |
| Port reserved by Windows | skip excluded ranges up front |
| Aether crashes or exits | immediate `Reconnecting`, log last lines, `E400` only if it repeats 3 times in 60 s (then Failed) |
| Aether prompts on stdin | impossible by design; if the process blocks without output for 3 s after start, treat as startup failure and capture output |
| Tunnel silently dead | passive stall detection then probe, then Reconnecting |
| Wi-Fi to cellular switch | debounce, probe, reconnect via cache if needed |
| Sleep and wake | probe after resume |
| Engine/service crash while connected | TUN vanishes, journal cleanup on restart, UI shows state `Failed` with `E400`, auto-reconnect if `restore_last_state` |
| UI crash or close | tunnel continues; UI reattaches by IPC and shows the real state |
| Double launch of the UI | focus the existing window (single-instance via mutex or lock + IPC focus message) |
| Second user logs into the same Windows or Linux machine | only one active tunnel; second UI shows busy `E300` clearly |
| Another VPN revokes ours (Android) | `onRevoke`, notice `E230`, no crash |
| VPN permission revoked or never granted | onboarding or in-flow prompt; denial shows `E220` |
| Notification permission denied | continue; foreground notification still posted |
| Settings file corrupt | move to `.corrupt`, load defaults, notice, no crash |
| Disk full | atomic writes fail safely, keep old file, notice |
| Helper service not running (desktop) | `E200`; the UI offers "تلاش برای راهاندازی سرویس" (start service via the OS service API with elevation) |
| App upgrade while connected | installer stops service gracefully (cleanup), replaces, restarts; `restore_last_state` reconnects |
| IPv6-only network | `ip_version` Auto chooses V6/Dual; test that the ladder still works |
| MTU black hole | MTU 1280 default; if large transfers stall while small succeed, log a hint (no auto-tuning in v1) |
| Low memory kill (Android) | foreground service sticky restart; journal cleanup; reconnect if restored |
| Rapid toggle spam | section 7.1 and 7.9 |
| Antivirus quarantines `wintun.dll` | `E210`, documented in QA manual |
| Unsupported Linux (no systemd) | the TUN scope shows disabled with Persian explanation; system proxy still works if the DE is supported |

---

## 12. DESIGN SYSTEM

### 12.1 Design read (Taste Skill brief inference, declared once)
"A quiet precision instrument. Engineered like a system utility, not a marketing VPN. One control, no decoration, flat surfaces, hairlines instead of shadows, motion that feels physical." Reference feel: Windscribe's structure (one primary control, two-row bottom selector) and Apple's system apps for motion. Persian-first typography.

### 12.2 The three locks (never relax)
1. **Color lock:** one accent. Accent = the system accent color (Windows accent, Android dynamic color, Linux portal accent). If none is available the accent equals the primary text color (monochrome). No second brand color. The only semantic exception is a single desaturated error tone.
2. **Shape lock:** ALL corner radii are 0. This includes buttons, dialogs, bottom sheets, text fields, switches, chips, progress, scrollbars, snackbars (use a custom flat toast), tooltips and ripples. Override every Material 3 component theme with `RoundedRectangleBorder(borderRadius: BorderRadius.zero)` and `StadiumBorder` banned. Replace splash/ripple with a flat press tint. The OS-controlled launcher icon mask and Android 12 splash are the only exceptions (section 8.3).
3. **Theme lock:** follow the system light/dark setting automatically. No in-app theme toggle. Dark and light have identical hierarchy and contrast.

### 12.3 Tokens

Neutral surfaces (off-black and off-white, never pure):

| Token | Dark | Light |
|---|---|---|
| `surface` | `#0E0F10` | `#F4F4F2` |
| `surface_raised` | `#151618` | `#FBFBFA` |
| `hairline` | `#2A2C2F` | `#D9DAD6` |
| `text_primary` | `#ECEDEE` | `#161718` |
| `text_secondary` | `#9A9DA1` | `#6A6D70` |
| `scrim` | black at 55% | black at 35% |
| `error` | `#E0735F` | `#B3412F` |
| `accent` | system accent adjusted so contrast against `surface` is at least 4.5:1 (adjust OKLCH lightness only); fallback `text_primary` | same rule |

Text on accent fill uses whichever of `surface` or `text_primary` has contrast of at least 4.5:1. Verify contrast of every token pair in a unit test (WCAG AA).

Spacing: 4 dp grid. Screen padding 20 dp (mobile), 24 dp (desktop). Row height 56 dp. Minimum touch target 48 dp. Content max width 420 dp, centered.

Type (Vazirmatn variable; generous line height for Persian):
| Role | Size/line | Weight |
|---|---|---|
| timer | 40/48 | 300 |
| title | 22/32 | 600 |
| row_title | 16/28 | 500 |
| body | 15/26 | 400 |
| label | 13/22 | 500 |
| caption | 12/20 | 400 |
Digits always use the Persian digit helper (14.5). The connection timer lays each digit in a fixed-width box so it never jitters.

Borders: 1 dp hairlines. No drop shadows. No blur. No gradients. No glow.

### 12.4 Motion tokens (Apple-like; all animations interruptible with preserved velocity)
- Ease standard: `Cubic(0.32, 0.72, 0.0, 1.0)`.
- Spring snappy: mass 1, stiffness 420, damping ratio 0.9 (controls, toggles, press).
- Spring gentle: mass 1, stiffness 220, damping ratio 0.85 (sheets, state change).
- Durations: micro 120 ms, standard 280 ms, emphasized 480 ms, sheet 420 ms. Stagger step 28 ms.
- Retargeting rule: every animation is driven by a controller that can be retargeted mid-flight, continuing from the current value and velocity (use `SpringSimulation` with `animateWith`). Never restart from zero.
- Reduced motion (system setting): replace springs and translations with a 120 ms cross-fade.
- Frame budget: 8.3 ms per frame at 120 Hz. No animation touches layout of the whole tree; wrap animated painters in `RepaintBoundary`; avoid `Opacity` on large subtrees, `BackdropFilter`, `saveLayer`; pause all animation controllers when the window is hidden or minimized.

Transitions:
- Page push/pop: 24 dp slide from the reading-start side (RTL aware, so from the right) plus fade, 280 ms ease standard; Android predictive back enabled.
- Sheets: translate from the bottom with spring gentle, scrim fades 280 ms; dismiss by drag with velocity-aware fling; sharp corners, a 24 x 2 dp rectangular grabber.
- Value changes (timer digits, speeds): cross-fade 120 ms with 6 dp upward drift; no counting animations.
- Press: scale 0.98 plus tint overlay of 8% `text_primary`, 90 ms in, 160 ms out (spring snappy).
- Scroll physics: bouncing (iOS-style) on all platforms.
- Haptics (Android): light impact on press, medium on connected, heavy double-tap on failure.

### 12.5 The connect control (brand centerpiece, deterministic spec)

Drawn with one `CustomPainter` inside a `RepaintBoundary`. Concept: a planet square with a thin ring band (Saturn = زحل). Size: a 176 x 176 dp square hit area.
- Frame: square, side 176, 1 dp `hairline` stroke.
- Planet: centered square, side 72 dp.
  - Idle: no fill, 1.5 dp stroke `text_secondary`.
  - Connecting/Reconnecting: no fill, 1.5 dp stroke `accent`.
  - Connected: filled `accent`. Fill grows from the center outward as a scaling square (0 to 1) over 480 ms emphasized with spring gentle.
  - Failed: stroke `error` for 600 ms, then back to idle.
- Ring: a rectangle 232 x 2 dp centered on the planet, rotated by angle theta, drawn in two halves to fake depth: the upper half (y above center) is drawn BEFORE the planet (behind it), the lower half is drawn AFTER the planet (in front), using two clip rectangles. Color: `text_primary` at 70% in idle, `accent` when connecting/connected.
  - Idle theta = -20 degrees.
  - Connecting/Reconnecting: theta orbits continuously at 0.4 turn per second (linear), and the ring passes in front/behind correctly because of the two-half drawing.
  - Connected: theta settles to -20 degrees with spring snappy overshoot of about 4 degrees.
  - Failed: theta snaps to 0 degrees.
- Stage ticks: four 12 x 2 dp ticks, one centered on each side of the frame, drawn just outside it. During connecting, tick i fills with `accent` when the engine reports its stage (Prepare, FindGateway, BuildTunnel, VerifyPath); ticks clear on idle; all turn `error` for 600 ms on failure. These show real progress, not decoration.
- Pressed: whole control scales 0.98 (spring snappy).
- Accessibility: semantics label changes per state (Persian strings in 14.3), button role, minimum target met.

### 12.6 Optimistic UI and spam behavior
- A tap immediately changes the control's presented state (target animation starts at once), while the engine confirms asynchronously. The presented state converges to the engine's real state; if they disagree for more than 2 s the engine's state wins with the standard transition.
- Tap while Idle or Failed: `desired=up`.
- Tap while Connecting/Preparing/Reconnecting: arm the inline cancel confirmation (below); this tap does NOT change desired.
- Tap while Connected: `desired=down` immediately (setting `confirm_disconnect` does not exist in v1; do not add).
- Tap while Disconnecting: `desired=up` (the engine finishes teardown first, then connects).
- **Cancel confirmation:** first tap during connecting shows the hint "برای لغو دوباره بزنید" in place of the sub-label for 3 s and the control's frame stroke switches to `accent` for that time. A second tap within 3 s sets `desired=down`. After 3 s without a tap the hint reverts. Additionally, leaving the screen with the system back gesture during connecting never cancels. Keyboard (desktop): Space or Enter activates the control.

### 12.7 Taste Skill ban list, adapted (all enforced)
No emoji. No em or en dashes in copy. No gradients, mesh, glow, blur, glass, or drop shadows. No pills, no circular buttons, no rounded anything. No decorative status dots (a state is shown by the control itself). No three-equal-card rows. No fake charts or dashboards: the only graphic is the control; if a speed sparkline is added it must plot real counter data, 60 samples, hairline stroke (optional, off by default is acceptable; if included keep it in the stats row only). No stock imagery, no illustrations beyond the brand mark. No version badges or "BETA" tags on the main screen. No scroll cues. No hand-rolled decorative icons: use `Icons.*_sharp` (list: power_settings_new, settings, route (alt_route), apps, article (logs), info, close, arrow_back_ios_new mirrored by RTL, add, delete_outline, check, warning_amber, content_copy, shield).
Hierarchy discipline for the main screen (analog of "hero discipline"): it fits one viewport at 360 x 640 dp with no scrolling; the connect control is visible without interaction; title at most two lines; one primary action.

