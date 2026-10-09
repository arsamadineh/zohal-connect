# PROGRESS.md - Zohal Connect Task Tracker

## Phase 0: Study and Experiments
- [x] T0.1 Resolve latest Aether release, record lockfile, clone at tag, read docs
- [x] T0.2 Obtain Linux x86_64 release binary, verify SHA256, record help in `docs/AETHER_NOTES.md`
- [x] T0.3 Fill flag mapping table in `docs/AETHER_NOTES.md` from real `--help`
- [x] T0.4 Experiment E1: Subprocess harness with full flags, stdin closed, capture logs
- [x] T0.5 Experiment E2: Readiness and SOCKS port open timing (p50/p95, 10 runs each)
- [x] T0.6 Experiment E3: Concurrency test with two Aether instances
- [x] T0.7 Experiment E4: Data check `curl -x socks5h://... https://1.1.1.1/cdn-cgi/trace` returns `warp=on`
- [x] T0.8 Experiment E5: TUN front end (`tun2proxy` in netns, TCP/UDP/QUIC/IPv6, throughput)
- [x] T0.9 Experiment E6: Linux policy-routing loop prevention validation
- [x] T0.10 Experiment E7: Windows socket bind analysis and patch feasibility
- [x] T0.11 Experiment E8: Android execution analysis (`libaether.so` from nativeLibraryDir)
- [x] T0.12 Aether supply strategy decision recorded
- [x] Phase 0 Gate: `docs/AETHER_NOTES.md` complete with numbers and verified items

## Phase 1: Engine Core (Linux, Fake Aether)
- [x] T1.1 `zohal-proto`: types, IPC messages, settings schema with validation, error codes
- [x] T1.2 `zohal-engine`: supervisor reconcile loop with level-triggered watch channel and settle window
- [x] T1.3 Fake-Aether test harness (delays, failures, port readiness, crash simulation)
- [x] T1.4 Auto ladder and rung memory implementation
- [x] T1.5 Cache system (`endpoints.json`, `rungs.json`, atomic IO, corruption recovery)
- [x] T1.6 Journal and idempotent undo system
- [x] T1.7 IPC server and client implementation (`interprocess` newline-delimited JSON)
- [x] T1.8 Log ring buffer (2000 events) and diagnostic export
- [x] T1.9 Error taxonomy implementation
- [x] T1.10 Unit tests and property test (10,000 toggles x 20 seeds)
- [x] T1.11 IPC parser fuzz test
- [x] Phase 1 Gate: All tests green, zero leaked processes/journal entries, clippy/fmt clean

## Phase 2: Linux Platform with Real Aether
- [x] T2.1 Aether process supervisor (lifecycle, flag generation, stdin closed, kill escalation)
- [x] T2.2 `tun2proxy` integration with traffic counters and TunFrontend trait
- [x] T2.3 Linux policy routing (`zohal0`, fwmark, suppress_prefixlength, tables, undo journal)
- [x] T2.4 DNS management (`systemd-resolved`, `resolvectl`, fallback `/etc/resolv.conf`)
- [x] T2.5 IPv6 routing and leak prevention
- [x] T2.6 Free port and TUN subnet candidate probing
- [x] T2.7 Health monitor (passive counters, active trace probe, network change, sleep/wake)
- [x] T2.8 Desktop system proxy scope (`zohald user` for GNOME/KDE with journal snapshot/restore)
- [x] T2.9 `zohald` CLI commands (`service`, `user`, `install`, `uninstall`, `cleanup`, `status`)
- [x] T2.10 systemd unit file (`zohald.service`) with hardening
- [x] T2.11 nfpm packaging config (.deb and .rpm)
- [x] Phase 2 Gate: netns e2e test, clean state verification, kill -9 recovery test, 1000 cycles

## Phase 3: Flutter UI Complete
- [ ] T3.1 Design tokens, Material 3 override theme (sharp corners, radius 0), motion tokens
- [ ] T3.2 Custom connect control `CustomPainter` (Saturn planet square, depth ring, 4 stage ticks)
- [ ] T3.3 Persian helper (`core/persian.dart`), digit conversion, LTR isolates, formatting
- [ ] T3.4 Complete Persian copy in `lib/l10n/strings_fa.dart` and `docs/STRINGS_FA.md`
- [ ] T3.5 `flutter_rust_bridge` wiring and Riverpod providers
- [ ] T3.6 Main screen implementation (header, connect control, stats, bottom group)
- [ ] T3.7 Mode sheet (روش اتصال) with square radios and advanced options
- [ ] T3.8 Routing screen (مسیریابی) with smart toggle and direct/block lists
- [ ] T3.9 Settings screen (تنظیمات) with sharp switches and grouped rows
- [ ] T3.10 Logs screen (گزارشها) with filtering and export
- [ ] T3.11 About screen (درباره) with AGPL notice and licenses
- [ ] T3.12 Onboarding flow (4 steps, introductions, permissions, mode, first connect)
- [ ] T3.13 Desktop window management, tray menu, single instance lock
- [ ] T3.14 System accent color extraction
- [ ] T3.15 Vazirmatn variable font subsetting
- [ ] T3.16 Widget tests, golden tests, RTL tests, digit lint test, contrast test
- [ ] Phase 3 Gate: `flutter analyze` zero issues, tests pass, pre-flight checklist verified

## Phase 4: Windows Platform
- [ ] T4.1 Windows platform module (Wintun adapter, IP Helper API, routes, metrics)
- [ ] T4.2 Windows DNS configuration and `ZohalDnsGuard` firewall rule
- [ ] T4.3 Loop prevention (Plan A patch or Plan B edge bypass routes)
- [ ] T4.4 Windows service host (`ZohalEngine`, power/network change handlers)
- [ ] T4.5 Windows system proxy scope (WinInet registry snapshot and restore)
- [ ] T4.6 Inno Setup 6 installer script with RTL Persian wizard
- [ ] T4.7 Windows CI workflows on `windows-latest`
- [ ] Phase 4 Gate: CI build, installer verified or documented in QA manual

## Phase 5: Android Platform
- [ ] T5.1 `ZohalVpnService` implementation in `:vpn` process
- [ ] T5.2 Foreground service notification (`zohal_status`, duration, disconnect action)
- [ ] T5.3 JNI bridge between Kotlin and Rust engine
- [ ] T5.4 Aether packaging and execution (`libaether.so` from nativeLibraryDir)
- [ ] T5.5 TUN fd passing to `tun2proxy` front end
- [ ] T5.6 Per-app split tunneling configuration
- [ ] T5.7 Quick Settings Tile (`ZohalTileService`), boot receiver, app shortcut
- [ ] T5.8 Permissions flow in onboarding (VPN consent, notifications, battery exemption)
- [ ] T5.9 Android CI workflow and emulator tests
- [ ] Phase 5 Gate: APK builds for all ABIs, emulator test passes or manual QA documented

## Phase 6: Hardening and Release
- [ ] T6.1 24-hour / extensive simulated soak testing with fake Aether
- [ ] T6.2 Security review against Section 10
- [ ] T6.3 Dependency audit (`cargo audit`, `cargo deny`)
- [ ] T6.4 Complete documentation deliverables (`README.md`, `ARCHITECTURE.md`, `QA_MANUAL.md`, etc.)
- [ ] T6.5 Release workflow dry run
- [ ] T6.6 Final audit against Section 19 pre-flight checklist
