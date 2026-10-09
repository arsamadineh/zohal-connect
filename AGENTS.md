# AGENTS.md - Zohal Connect Rules (Hard Constraints)

Follow these rules without exception. Never violate or relax them:

1. R1: No placeholders, no mock data, no TODO, no "implement later", no stubs, no fake dashboards. Record uncompleted features in `docs/KNOWN_LIMITS.md`.
2. R2: Never invent APIs, flags, crate functions, package names, or versions. Verify everything in real docs/source/help. Confirm [VERIFY] items in `docs/AETHER_NOTES.md` or `docs/DECISIONS.md`.
3. R3: Never claim something works unless executed. Record command and output in `docs/GATES.md`. Unrun items must be marked `NOT RUN: reason`.
4. R4: Do not ask questions. Use spec defaults. For undecidable issues, pick the safer option, record in `docs/DECISIONS.md`, and proceed.
5. R5: Three-attempt rule: If an error persists after 3 distinct fix attempts, stop, document in `docs/BLOCKERS.md`, apply fallback, and continue.
6. R6: Do not change scope. No unauthorized dependencies without a `docs/DECISIONS.md` justification.
7. R7: Small verified steps. After each task: build, test, commit (`git commit -m "phase-N: task"`). Keep repo buildable.
8. R8: Zero warnings policy: `cargo clippy --all-targets -- -D warnings`, `cargo fmt --check`, `flutter analyze`, and `dart format` must pass before every gate.
9. R9: Journal before modify: Every system change (route, DNS, proxy, firewall) is journaled before applied and undone idempotently.
10. R10: Never touch what Zohal did not create. Do not modify foreign routes, rules, adapters, firewall rules, or processes.
11. R11: No telemetry, no analytics, no update pings, no crash uploads. Only Cloudflare edge, Cloudflare reg API, and health probe.
12. R12: Pin exact dependencies. Document pins with dates in `docs/DEPENDENCIES.md`.
13. R13: Do not rewrite working code after its gate passed unless fixing a bug.
14. R14: Persian only in the UI. No English strings except proper nouns (protocol names) and technical values.
15. R15: Persian digits (۰-۹) in the UI. Latin digits only in logs, clipboard copies, filenames, and code.
16. R16: No em dashes or en dashes in user-visible copy. Use Persian comma "،", semicolon "؛", colon, or restructure.
17. R17: No emoji anywhere (UI, logs, docs, commit messages).
18. R18: Sharp corners only: Border radius 0 everywhere in app UI.
19. Reconcile Loop: Level-triggered `Supervisor` owning all system state. Single `desired` watch channel. Settle window 120 ms.
20. Crash safety: Journal with idempotent undo. Child cleanup with PDEATHSIG/Job Object/sweeper.
21. Resume protocol: Read `AGENTS.md`, `ZOHAL_SPEC.md`, `docs/PROGRESS.md`, `docs/DECISIONS.md`, `docs/BLOCKERS.md`. Continue with first unchecked task.
