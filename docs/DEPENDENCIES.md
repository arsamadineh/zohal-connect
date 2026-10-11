# DEPENDENCIES.md - Pinned Dependencies

This document records pinned versions and dates of all external tooling, binaries, and dependencies per Rule R12.

| Dependency | Version / Pin | Date Recorded | Source | Hash / Notes |
|---|---|---|---|---|
| Aether | v2.3.0 | 2026-10-10 | GitHub Release | `6175b67df370ab856bcee07fe85b524031903956` (see `third_party/aether.lock`) |
| Rust toolchain | stable (1.98+) | 2026-10-10 | rustup / distro | Required by Aether v2.3.0 and engine crates |
| Dart SDK | 3.13.5 | 2026-10-10 | pacman / distro | `cachyos-extra-v3/dart 3.13.5-1.1` |
| Flutter SDK | 3.47.7 (stable) | 2026-10-10 | Google Storage | `abaf9c5237` (Dart 3.13.5) |
| intl | 0.20.3 | 2026-10-10 | pub.dev | pinned localization dependency |
| Vazirmatn Font | 33.003 (Variable) | 2026-10-10 | GitHub Release | OFL-1.1 license, subsetted to 148 KB |
| tokio | 1.43 | 2026-10-10 | crates.io | async runtime |
| tun2proxy | 0.8.4 | 2026-10-10 | crates.io | pure-Rust TUN to SOCKS5 gateway |
| interprocess | 2.4 | 2026-10-10 | crates.io | local socket IPC with tokio |
| zbus | 5.19 | 2026-10-10 | crates.io | D-Bus communication |
| sd-notify | 0.5.0 | 2026-10-10 | crates.io | systemd Type=notify integration |
| proptest | 1.6 | 2026-10-10 | crates.io | property testing (10k toggles) |
| ureq | 2.12 | 2026-10-10 | crates.io | health verification probe; `socks-proxy` feature enabled so the probe can reach the local SOCKS5 port (`socks5://`) |
| socks (transitive via ureq `socks-proxy`) | 0.3.4 | 2026-10-11 | crates.io | SOCKS5 client used by ureq for the WARP trace probe |
| flutter_riverpod | 2.5.1 | 2026-10-10 | pub.dev | reactive state management |
| window_manager | 0.3.9 | 2026-10-10 | pub.dev | desktop window dimensions |
| tray_manager | 0.2.3 | 2026-10-10 | pub.dev | system tray integration |
| dynamic_color | 1.7.0 | 2026-10-10 | pub.dev | Android Material You dynamic coloring |
| fonttools | 4.66.1 | 2026-10-10 | pacman | font subsetting tool |
| cargo-ndk | latest at CI time | 2026-10-10 | crates.io (CI install) | builds `zohal-android` cdylib for 3 Android ABIs |
| Android NDK | r28 (via nttld/setup-ndk@v1) | 2026-10-10 | Google (CI install) | 16 KB page alignment for `libzohal_tun.so` |
| appimagetool | continuous | 2026-10-10 | GitHub Release (CI download) | assembles `Zohal-<ver>-x86_64.AppImage` |
