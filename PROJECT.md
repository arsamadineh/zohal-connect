# Project: Zohal Connect — Major Release

## Architecture
Zohal Connect is a cross-platform privacy and censorship-circumvention client (Linux desktop & Android).
The application is structured into two primary layers:
1. **Flutter Frontend (`app/`)**:
   - Presentation, state management (Riverpod), navigation, and user-facing features.
   - Core services: updater (`core/updater.dart`), window management (`main.dart`), tray service (`core/tray_service.dart`), node management, ping measurement, and Iranian localization/Persian formatting (`core/persian.dart`).
   - Platform interop: Unix domain socket IPC to daemon on desktop (`zohal-bridge`), and Android `VpnService` / JNI platform channel (`app.zohal.connect.TunBridge`).
2. **Rust Engine (`engine/crates/`)**:
   - `zohal-proto`: IPC protocol and shared data models (`ConnectionMode`, `CandidateConfig`, `EngineState`, `TunnelProtocol`).
   - `zohal-engine`: Supervisor, reconcile state machine, `TunnelBackend` trait, process monitoring, and exit IP verification.
   - `zohal-tun`: Userspace TUN driver wrapping `tun2proxy` listening on local SOCKS5.
   - `zohal-platform`: Native OS configuration (Linux policy routing `table 100`, fwmark `0x5a48`, unprivileged desktop proxy).
   - `zohald`: Desktop system daemon coordinating the supervisor, IPC socket, and TUN adapter.
   - `zohal-bridge`: Desktop client-side IPC library talking to `zohald`.
   - `zohal-android`: Android JNI bindings for packet routing through `tun2proxy`.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Instant Window & Logo Render | Render centered `BrandLogo(size: 72.0)` immediately on frame 1 in `app.dart` during async preference resolution | M1 | R1 / Survey 1 |
| 2 | Startup Non-Blocking Decoupling | Defer `updateInfoProvider` / GitHub network requests from initial startup to background timer | M1 | R1 / Survey 1 |
| 3 | Native Window Size Alignment | Set default GTK window size in `my_application.cc` directly to 400x680 to eliminate resize flicker | M1 | R1 / Survey 1 |
| 4 | Non-blocking Tray & IPC Probes | Ensure background asset extraction and daemon socket probes do not block main UI thread | M1 | R1 / Survey 1 |
| 5 | HTTP Range Resumable Downloader | Implement `ResumableDownloader` supporting `Range: bytes=X-`, HTTP 206 Partial Content, and partial `.part` file persistence | M2 | R2 / Survey 2 |
| 6 | Pause & Resume State Machine | Provide explicit pause, resume, and cancel handles in downloader service | M2 | R2 / Survey 2 |
| 7 | Network Drop Resilience | Auto-retry transient network interruptions up to 5 times with exponential backoff from last byte offset | M2 | R2 / Survey 2 |
| 8 | Byte Progress & Speed Tracking | Calculate received bytes, total size, percentage, and sliding-window download speed (bytes/sec) + ETA | M2 | R2 / Survey 2 |
| 9 | SHA256 Integrity Verification | Download `SHA256SUMS.txt`, compute hash with `crypto`, and verify before marking update ready | M2 | R2 / Survey 2 |
| 10 | Atomic Replacement & Clean Teardown | Ensure active VPN tunnel is terminated prior to AppImage restart on Linux, and resolve target ABI on Android | M2 | R2 / Survey 2 |
| 11 | Resumable Updater UI | Upgrade `UpdateDialog` to show pause/resume buttons, speed indicators, byte progress, and Persian formatting | M2 | R2 / Survey 2 |
| 12 | VLESS / VMess Data Models | Add `ConnectionMode::Custom` and `CustomNodeConfig` to `zohal-proto` supporting VLESS (Reality, gRPC, WS) and VMess | M3 | R3 / Survey 3 |
| 13 | Proxy Core Integration | Implement `CustomProxyBackend` generating minimal sing-box JSON configuration with SOCKS5 inbound | M3 | R3 / Survey 3 |
| 14 | SOCKS5 Tunnel Re-use | Plug proxy core's SOCKS5 listener directly into existing `tun2proxy` kernel TUN and Android JNI bridge | M3 | R3 / Survey 3 |
| 15 | Clean Teardown & Zombie Prevention | Enforce `SIGTERM -> SIGKILL -> child.wait().await` with `PR_SET_PDEATHSIG` and 120ms settle window | M3 | R3 / Survey 3 |
| 16 | Supervisor Exit IP Scheme Bug Fix | Change `socks5h://` to `socks5://` in `supervisor.rs:229` to fix `ureq` proxy initialization | M3 | R3 / Survey 3 |
| 17 | VLESS & VMess URI Parser | Implement Dart parser for `vless://` (UUID, security, reality params, flow, transport) and `vmess://` (base64 JSON) | M4 | R4 / Survey 3 |
| 18 | Batch & Subscription Import | Support importing multi-line configs and HTTP subscription endpoints | M4 | R4 / Survey 3 |
| 19 | Live TCP Latency Ping Probe | Measure non-blocking round-trip TCP handshake latency via `Socket.connect` with 2500ms timeout | M4 | R4 / Survey 3 |
| 20 | Country Flag & Node Selector UI | Build `NodesScreen` displaying protocol badges, latency, and sharp-cornered country flags (`borderRadius: 0`) | M4 | R4 / Survey 3 |
| 21 | Active Exit IP & Country Detection | Display public IPv4/IPv6 address and country code in connected state on MainScreen | M4 | R4 / Survey 3 |
| 22 | Multi-Manifest Version Bump | Bump version from `0.1.15` to `0.2.0` across 13 locations in pubspec, Cargo.toml, gradle, and packaging | M5 | R5 / Survey 1 |
| 23 | Comprehensive Quality Assurance | Verify zero errors in `flutter analyze`, clean `cargo check/clippy`, passing `flutter test` and `cargo test` | M5 | R5 / Survey 1 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | R1: Instant Launch & Opening Performance | Startup lifecycle, immediate BrandLogo on frame 1, deferred background/updater network calls, native window size alignment | none | DONE (SplashScreen, AnimatedSwitcher, 20.78ms avg cold start, 70/70 tests pass) |
| M2 | R2: Resumable & Bulletproof In-App Updater | ResumableDownloader with HTTP Range requests, pause/resume, network drop auto-retry, SHA256 verification, speed/ETA calculations, atomic replacement, and updated UpdateDialog UI | none | PLANNED |
| M3 | R3: Real VLESS / VMess & Custom Proxy Engine Integration | `zohal-proto` Custom mode, `zohal-engine` custom proxy backend with sing-box config generation and lifecycle management, `socks5h://` bug fix in `supervisor.rs`, clean teardown | none | PLANNED |
| M4 | R4: Configuration Selector, Live Ping Testing, Flags & IP Detection | VLESS/VMess link & subscription parser, `NodesScreen` UI with sharp corners, TCP latency ping probe with timeouts, country flag rendering, connected exit IP/country detection | M3 | PLANNED |
| M5 | R5: Release Version Bump & Quality Assurance | Version Bump across 13 locations, Comprehensive E2E Testing (Tiers 1-4 pass 100%), adversarial testing, `flutter analyze`, `cargo check/clippy/test`, and final verification | M1, M2, M3, M4 | PLANNED |

## Interface Contracts
### Flutter UI ↔ In-App Updater (`app/lib/core/updater.dart`)
- `ResumableDownloader`:
  - `Future<void> start({required UpdateInfo info, required Function(DownloadProgress) onProgress, required Function(File) onComplete, required Function(String) onError})`
  - `void pause()`
  - `void resume()`
  - `void cancel()`
- `DownloadProgress`:
  - `int bytesReceived`, `int totalBytes`, `double progressFraction`, `double speedBytesPerSec`, `Duration? estimatedTimeRemaining`

### Flutter UI ↔ Node Management (`app/lib/features/nodes/`)
- `NodeModel`:
  - `String id`, `String name`, `ProxyProtocol protocol` (vless, vmess, aether), `String server`, `int port`, `String countryCode`, `int? pingMs`, `bool isReachable`, `Map<String, dynamic> rawConfig`
- `NodeParser`:
  - `List<NodeModel> parseText(String input)` (handles single URI, multi-line, base64 subscriptions)
- `PingService`:
  - `Future<int?> measurePing(String host, int port, {Duration timeout = const Duration(milliseconds: 2500)})`

### Flutter UI ↔ Rust Daemon IPC (`zohal-proto`)
- `ConnectionMode`:
  - `Aether(AetherConfig)` | `Custom(CustomNodeConfig)`
- `CustomNodeConfig`:
  - `protocol: String` ("vless" | "vmess"), `server: String`, `port: u16`, `uuid: String`, `security: Option<String>`, `sni: Option<String>`, `transport: Option<String>`, `path: Option<String>`, `fingerprint: Option<String>`
- `CandidateConfig`:
  - `mode: ConnectionMode`, `socks_port: u16`

## Code Layout
- `app/lib/app.dart`: App entry widget, router, splash/initial render
- `app/lib/main.dart`: Desktop window manager setup, runApp
- `app/lib/core/updater.dart`: ResumableDownloader, SHA256 verification, platform installer
- `app/lib/features/about/update_dialog.dart`: Update dialog UI with pause/resume and speed
- `app/lib/features/nodes/`: Node models, URI parsers, ping service, NodesScreen UI
- `app/lib/features/connect/main_screen.dart`: Main screen with connected IP/location, active node display
- `engine/crates/zohal-proto/src/`: Protocol data models and serialization
- `engine/crates/zohal-engine/src/`: Supervisor, custom proxy backend, process lifecycle
- `packaging/`: Manifests, AppImage and installer scripts
