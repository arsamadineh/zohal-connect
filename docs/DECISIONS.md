# DECISIONS.md - Architectural & Design Decisions

This document records deliberate design and technical decisions made for Zohal Connect, adhering to Rule R4 and R6.

## 001: Pinned Aether Upstream Release
- **Date**: 2026-10-10
- **Context**: Spec requires resolving the latest Aether release as of implementation start.
- **Decision**: Pinned upstream release `v2.3.0` (commit `6175b67df370ab856bcee07fe85b524031903956`, released 2026-10-04). SHA256 hashes recorded in `third_party/aether.lock`.
- **Status**: Accepted.

## 002: Aether Binary Distribution Strategy (T0.12)
- **Date**: 2026-10-10
- **Context**: T0.12 requires deciding whether to download official binaries or build from source.
- **Decision**: In accordance with Section 3.2 T0.12 default:
  - Linux (x86_64 and arm64): Official release binaries verified by SHA256.
  - Windows: If patch for `IP_UNICAST_IF` / `IPV6_UNICAST_IF` is feasible (T0.10), build patched Aether binary in CI; otherwise use official release binary with Plan B edge bypass routes.
  - Android: Use release binary / source build via cargo-ndk.
- **Status**: Accepted.

## 003: Proptest and Ureq Crate Authorization
- **Date**: 2026-10-10
- **Context**: Sections 7.9 and 10 explicitly require property testing (10,000 toggles) and fuzz testing with proptest or cargo-fuzz. Section 7.6 requires a tiny dedicated health probe client (ureq or rustls).
- **Decision**: Authorize `proptest = "1.6"` strictly as a dev-dependency for property and fuzz tests, and `ureq = "2.12"` for the verification probe client.
- **Status**: Accepted.
