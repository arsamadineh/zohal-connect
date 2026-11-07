# E2E Test Infra: Zohal Connect

## Test Philosophy
- Opaque-box, requirement-driven derived from `ORIGINAL_REQUEST.md`.
- No dependency on implementation design.
- Methodology: Category-Partition + Boundary Value Analysis + Pairwise Combinatorial + Real-World Workload Testing.

## Feature Inventory & Test Coverage
| # | Feature | Requirement | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|---|---------|-------------|:------:|:------:|:------:|:------:|
| 1 | Instant Launch & Logo Render | R1 | 5 | 5 | ✓ | ✓ |
| 2 | Startup Non-Blocking Decoupling | R1 | 5 | 5 | ✓ | ✓ |
| 3 | Native Window Size Alignment | R1 | 5 | 5 | ✓ | ✓ |
| 4 | Resumable Downloader (Range HTTP) | R2 | 5 | 5 | ✓ | ✓ |
| 5 | Pause & Resume State Machine | R2 | 5 | 5 | ✓ | ✓ |
| 6 | Network Drop Resilience & Retry | R2 | 5 | 5 | ✓ | ✓ |
| 7 | Byte Progress & Speed Tracking | R2 | 5 | 5 | ✓ | ✓ |
| 8 | SHA256 Integrity Verification | R2 | 5 | 5 | ✓ | ✓ |
| 9 | Atomic Replacement & Teardown | R2 | 5 | 5 | ✓ | ✓ |
| 10 | VLESS URI & Parameter Parsing | R3 | 5 | 5 | ✓ | ✓ |
| 11 | VMess URI & Parameter Parsing | R3 | 5 | 5 | ✓ | ✓ |
| 12 | Proxy Core & SOCKS5 Routing | R3 | 5 | 5 | ✓ | ✓ |
| 13 | Clean Teardown & Zombie Prevention | R3 | 5 | 5 | ✓ | ✓ |
| 14 | Node Selector UI & Storage | R4 | 5 | 5 | ✓ | ✓ |
| 15 | Live TCP Ping Measurement | R4 | 5 | 5 | ✓ | ✓ |
| 16 | Country Flag Mapping & Sharp Rules | R4 | 5 | 5 | ✓ | ✓ |
| 17 | Public Exit IP & Country Detection | R4 | 5 | 5 | ✓ | ✓ |
| 18 | Multi-Manifest Version Bump | R5 | 5 | 5 | ✓ | ✓ |

## Test Architecture
- **Flutter Test Runner**:
  - Command: `/opt/flutter/bin/flutter test`
  - Targets:
    - Unit tests: `app/test/core/` (updater, persian, tray, ping, parsers)
    - Widget tests: `app/test/features/` (splash, main_screen, update_dialog, nodes_screen)
    - Sharp design tests: `app/test/design/` (zero border radius validation)
  - Pass/Fail semantics: Exit code 0, all tests pass.
- **Rust Engine Test Runner**:
  - Command: `cargo test --workspace`
  - Targets:
    - Protocol tests: `engine/crates/zohal-proto`
    - Engine & supervisor tests: `engine/crates/zohal-engine`
    - Platform tests: `engine/crates/zohal-platform`
    - TUN tests: `engine/crates/zohal-tun`
  - Pass/Fail semantics: Exit code 0, all tests pass.
- **Static Analysis & Linting**:
  - Command: `/opt/flutter/bin/flutter analyze` (zero issues)
  - Command: `cargo clippy --workspace --all-targets` (zero warnings)

## Real-World Application Scenarios (Tier 4)
| # | Scenario | Features Exercised | Complexity |
|---|----------|--------------------|------------|
| 1 | Cold Launch without Internet | Instant BrandLogo render, no blocking network calls, graceful offline startup | High |
| 2 | Flaky Network Update with Pause/Resume | Resumable download across artificial drops, Range 206 header validation, SHA256 verification | High |
| 3 | Import VLESS Reality & Switch from Aether | Parse Reality link, start sing-box backend, stop Aether backend, zero zombie processes or leaked ports | High |
| 4 | Batch Import Subscriptions & Ping Ranking | Parse multi-line and base64 configs, run concurrent live pings with timeout, sort by latency, display flags | High |
| 5 | Connected State Exit IP Resolution | SOCKS5 tunnel active, ureq / client resolves public exit IP and country code, UI renders flag and IP | High |

## Coverage Thresholds
- Tier 1: ≥5 per feature (basic happy path)
- Tier 2: ≥5 per feature (boundaries, corrupt configs, zero sizes, network drops, invalid schemes)
- Tier 3: Cross-feature integration (e.g. updater + offline, node switch + ping, teardown + restart)
- Tier 4: ≥5 realistic end-to-end scenarios
