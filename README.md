# Zohal Connect | قندشکن زحل

**Zohal Connect** (Persian: **قندشکن زحل**; short: **زحل**) is a cross-platform censorship-circumvention client for Linux, Windows, and Android, built on top of the open-source **Aether** core (Cloudflare WARP over MASQUE/WireGuard).

## Features
- **Fast Connection**: Sub-2-second warm connect via persistent endpoint cache and parallel Auto ladder.
- **System-Wide Tunneling**: High-performance TUN interface with policy routing and zero network conflicts.
- **Crash-Safe Architecture**: Level-triggered supervisor, JSONL write-ahead journal, and idempotent undo recovery.
- **Zero Configuration Leaks**: DNS leak protection, IPv6 isolation, and automated split-routing for domestic (.ir) sites.
- **Precision User Interface**: Sharp-cornered, Persian-only RTL interface following Material 3 guidelines with zero border radius.
- **Absolute Privacy**: Zero analytics, zero telemetry, zero crash uploads, no user accounts.

## Project Structure
```
zohal-connect/
  engine/                          Rust engine workspace
    crates/
      zohal-proto/                 IPC protocols, settings schema, error taxonomy
      zohal-engine/                Supervisor, Auto ladder, cache, journal, prober
      zohal-platform/              Linux policy routing, Windows Wintun, proxy scope
      zohal-tun/                   tun2proxy frontend and packet counters
      zohald/                      Daemon binary (service, user, cleanup, status)
      zohal-bridge/                Flutter FFI/IPC bridge client, D-Bus accent query
  app/                             Flutter RTL application
    lib/                           Main UI, design system, custom Saturn connect control
    test/                          Unit, widget, and contrast tests
  packaging/                       Packaging configurations (.deb, .rpm, Inno Setup)
  docs/                            Architecture, decisions, gates, and QA manuals
```

## Building

### Engine (Rust)
Prerequisites: Rust 1.80+ (edition 2021).
```bash
cd engine
cargo build --release -p zohald
cargo test --all
```

### Application (Flutter)
Prerequisites: Flutter 3.19+ and Dart 3.0+.
```bash
cd app
flutter pub get
flutter analyze
flutter test
flutter build linux --release
```

## License
Zohal Connect is released under the [AGPL-3.0 License](LICENSE). Built upon the Aether core by CluvexStudio.
