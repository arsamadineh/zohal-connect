# ARCHITECTURE.md - Zohal Connect Architectural Blueprint

## 1. System Overview

Zohal Connect (Persian: **قندشکن زحل**; short: **زحل**) is a cross-platform censorship-circumvention client for Linux, Windows, and Android, built on top of the open-source Aether core (Cloudflare WARP over MASQUE/WireGuard).

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

## 2. Process & Privilege Model
- **UI Process (Flutter/Dart)**: Runs unprivileged as standard user. Never requires administrator or root rights.
- **Engine Process (`zohald service`)**: Runs as a hardened system service (systemd on Linux, Windows Service on Windows) to manage TUN network devices, policy routing, and DNS configuration.
- **User Proxy Mode (`zohald user`)**: Runs unprivileged per-user, managing desktop proxy settings without TUN.
- **Android Process (`:vpn`)**: Android runs `ZohalVpnService` in an isolated `:vpn` process hosting the engine via JNI.

## 3. Reconcile Loop & State Machine
The core engine is level-triggered:
- Desired state is communicated via a single `tokio::sync::watch` channel.
- A 120 ms settle window collapses rapid toggles into the final user intent.
- Single `Supervisor` actor owns all state transitions.
- The pipeline transitions through:
  `Idle -> Preparing -> Connecting -> Connected -> Reconnecting -> Disconnecting -> Failed`.
- Every transition stage (Prepare, FindGateway, BuildTunnel, VerifyPath) is reported in real-time.

## 4. Crash Safety & Journaling
- Every network configuration change (route addition, rule insertion, DNS override, proxy mutation) is logged to an fsync'd JSONL journal before application.
- On startup, any lingering journal actions are undone idempotently in reverse order.
- Child processes are bound to supervisor lifecycle via `PR_SET_PDEATHSIG` (Linux), Windows Job Objects (`KILL_ON_JOB_CLOSE`), and process sweepers.

## 5. Threat Model & Limitations
- **Local Proxy Port**: Aether opens a local SOCKS5 listener on `127.0.0.1` on a dynamically selected random port (20000-59999). It does not require authentication; binding exclusively to loopback mitigates remote access.
- **Exit Traffic**: Exit traffic is terminated at Cloudflare edge; Cloudflare observes destination IPs and TLS SNI.
- **Soft Kill Switch**: The kill switch holds the TUN interface closed during reconnections. If the service itself crashes, the OS drops the TUN interface and normal direct connectivity resumes.
