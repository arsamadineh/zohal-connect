# ZOHAL CONNECT: PHASE 9 AND 10 (SPEED PROGRAM, RESILIENCE, AUTO-UPDATE)

Amends `ZOHAL_SPEC.md`. If this file and the old spec disagree, THIS FILE WINS.
Repo: `https://github.com/arsamadineh/zohal-connect`. Current tag at time of writing: `v0.1.4`.
Written 2026-10-10 from the audit report of commit `8b0eb34`.

---

## 0. NOTE FOR THE HUMAN (delete before pasting)

1. Paste this whole file as the first message. Keep it saved in the repo as `docs/PHASE9_SPEC.md`.
2. You must do three human steps (the agent cannot do them safely): create the signing key (section 7.1), add GitHub secrets, and publish releases as NORMAL releases (not "pre-release").
3. The updater only works from the first version that contains it. Updating from v0.1.4 to the first updater version is a one-time manual install.
4. "Chinese secret bypass methods" do not exist as secrets. The real techniques (Reality, Hysteria2, TUIC, uTLS, zapret, sing-box, mihomo) are all open source and documented. Section 4 takes the parts that are applicable to Zohal (Aether is a WARP client, there is no own server) and turns them into measurable tasks.
5. "1000x faster" is not measurable. The physical floor is network round trips to Cloudflare. This prompt forces measurement and keeps only changes that provably help.

---

## 1. HOW YOU MUST WORK (READ TWICE)

You are a coding agent. You make small mistakes often. These rules exist to stop them.

### 1.1 Iron rules
1. One task at a time, in the order written. Do not start the next task before the current "Done when" is true.
2. Never invent a flag, crate function, package, file path or number. Before using any API read its real signature:
   - Rust: open `https://docs.rs/<crate>/<exact version in Cargo.lock>/` or read the crate source in `~/.cargo/registry`.
   - Aether: run `aether --help` and read the real output.
   - Dart: read the package page on pub.dev or its source in `~/.pub-cache`.
   Items marked `[VERIFY]` MUST be checked this way and the result written in `docs/DECISIONS.md`.
3. No placeholders, no TODO, no stubs, no fake data, no `unwrap()`/`expect()` in non-test Rust, no `print`/`println!` debugging, no commented-out code.
4. Never say "should work". Run it. Paste the command and the real output summary in `docs/GATES.md`. If you cannot run it, write `NOT RUN: reason`.
5. Numbers in docs must come from a real measurement you ran. Never write a number you did not measure.
6. Persian text: write it ONLY from the copy bank in section 6, copied exactly. In source code write the half-space as an escape (`\u200c` in Dart and Kotlin, `\u{200c}` in Rust). Never type Persian freehand. After any text change run `tools/lint-persian.sh`.
7. No em dashes, no en dashes, no emoji anywhere (UI, docs, commit messages).
8. New dependency rule: use the newest version that is at least 30 days old unless a newer one fixes a security issue. Add it with `cargo add <crate>` or `flutter pub add <pkg>`, then run `cargo tree -p <crate> --depth 1` to see what came with it. Record in `docs/DEPENDENCIES.md`.
9. Commit after each task with message `phase9: <task id> <short>`. Never commit a failing build.
10. When you change any Rust function used by Dart, re-run `flutter_rust_bridge_codegen generate` and never hand-edit generated files.

### 1.2 Build Doctor (follow this when ANY build, test or analyze fails)
1. Read ONLY the first error. Ignore the rest, they are often consequences.
2. Copy the first error and its file:line into a scratch note.
3. Open that file at that line. Read 30 lines around it.
4. Make the smallest possible fix for that one error. Do not refactor. Do not add `#[allow(...)]` or `// ignore`.
5. Re-run the same command. Repeat from step 1.
6. After 3 failed fixes for the same error: read the library docs for the exact types involved, then try a simpler design (clone a small value, use an owned `String`, add a scoped block, split the function). If still failing after 3 more tries: write `docs/BLOCKERS.md` and use the stated fallback.
7. Rust-specific fixes you will need often:
   - "future cannot be sent between threads": a `std::sync::MutexGuard` or `RefCell` borrow lives across an `.await`. Put the locked part in a `{ }` block that ends before the `.await`, or copy the data out first.
   - "borrowed value does not live long enough" in a spawned task: move owned data in (`let x = x.clone(); tokio::spawn(async move { ... })`).
   - "trait bound not satisfied": read the full note under the error, it names the missing trait; derive it or implement it.
   - Mismatched error types with `?`: add `#[error(transparent)] Io(#[from] std::io::Error)` style variants to your `thiserror` enum.
   - Never block inside async code: no `std::thread::sleep`, no `std::process::Command::output()`, no `std::fs` loops of unbounded size. Use `tokio::time::sleep`, `tokio::process::Command`, or `tokio::task::spawn_blocking`.
8. Flutter-specific: run in this order: `flutter pub get`, `flutter_rust_bridge_codegen generate` (if Rust API changed), `flutter analyze`, `flutter test`. Use `flutter clean` only as the last resort.
9. Gradle/Kotlin: run `./gradlew :app:assembleDebug --stacktrace`, read the first "What went wrong". Always use `PendingIntent.FLAG_IMMUTABLE`. Check nullability instead of using `!!`.

### 1.3 Code style rules (so your code stays simple)
- Functions at most 60 lines. One job per function. Early returns.
- Plain types. No clever generics, no macros you invented, no trait objects unless a trait already exists.
- Every error is a `thiserror` enum variant with a clear name. No `Box<dyn Error>` in library crates.
- No global mutable state. Pass dependencies in constructors.
- All time values are `Duration`; all sizes `u64` bytes. Name units in identifiers (`timeout_ms`, `size_bytes`).
- Every public function has a unit test or is covered by an integration test.

### 1.4 One command to check everything: `tools/check-all.sh` (create it first)
Create this file, make it executable, and run it before every commit:
```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
echo "== rust"
(cd engine && cargo fmt --all -- --check && cargo clippy --workspace --all-targets -- -D warnings && cargo test --workspace)
echo "== flutter"
(cd app && dart format --set-exit-if-changed lib test && flutter analyze && flutter test)
echo "== lints"
./tools/lint-persian.sh
./tools/lint-no-stubs.sh
echo "ALL CHECKS PASSED"
```
Create `tools/lint-no-stubs.sh`: it greps `engine/crates/*/src`, `app/lib`, `app/android/app/src/main` (excluding tests) for `TODO|FIXME|XXX|unimplemented!|todo!|placeholder|mock|dummy|fake_` and for `.unwrap()` / `.expect(` in non-test Rust, printing every hit and exiting 1 if any. In each Rust crate root add `#![cfg_attr(not(test), deny(clippy::unwrap_used, clippy::expect_used))]`.
Create `tools/lint-persian.sh` (if it exists already, extend it) to fail when a UI string contains: a Persian word starting with `می`/`نمی` followed directly by a Persian letter without U+200C, a plural suffix `ها`/`های` attached to a word that should have a half-space, an ASCII digit in UI copy, an em dash, an en dash, or an emoji. Keep an allow-list file `tools/persian-allow.txt` for legitimate exceptions.

---

## 2. AUDIT OF THE LAST REPORT (do these first)

The last report contains numbers that need correcting before more work is built on them.

Facts from the report:
- `zohald bench connect --runs 20` produced a summary with **N=7**. That means only 7 of 20 runs finished successfully. 13 failures were hidden. **That is a 35% success rate, not acceptable.**
- "Find Gateway" mean was **4229 ms**, min 3962 ms. Rung 1 has a **4 second deadline**. A stage that always lands near its own deadline usually means rung 1 is timing out every time and a later rung is doing the work, or a fixed wait of about 4 seconds exists somewhere.
- The "baseline 25,000 to 60,000 ms" was not measured in the report, only claimed.
- The TCP verify in the report is a SOCKS5 CONNECT to 1.1.1.1:443. That proves the PROXY path only. In TUN mode the real tunnel path (kernel route to TUN to tun2proxy to SOCKS) is not verified.
- Rung 1 is `h2_proven_only: true` with `use_cache: true`. On a fresh install the cache is empty, so this rung may have nothing to use and fail by design.

### TASK 2.1 Make the benchmark honest
Goal: the benchmark never hides a failure.
Steps:
1. In `zohald bench connect`, record for EVERY run: `run_index`, `ok` (bool), `failure_reason` (string, the error code and last Aether log lines), `winning_rung`, `winning_transport`, `used_cache` (bool), and the timeline (section 3, TASK 3.1).
2. Print: `runs_started`, `ok`, `failed`, and a table of failure reasons with counts.
3. Print percentiles (p50, p95) over OK runs only, and say so.
4. Write the full per-run JSON to `docs/perf/bench-<YYYYMMDD-HHMM>.json` (create the folder).
5. Add `--label <text>` to tag runs (for example `baseline`, `after-racing`).
Verify: run `zohald bench connect --runs 20 --label audit`. Paste `runs_started/ok/failed` and the failure table into `docs/PERF.md`.
Done when: the summary shows exactly 20 runs accounted for (ok + failed = 20).

### TASK 2.2 Find why 13 of 20 failed
Steps:
1. Read the failure table from 2.1. Group by reason.
2. For each reason, run the failing scenario by hand: start `aether` with the exact flags the engine used (print the full command line in the bench log; never hide it) and watch its output with timestamps: `AETHER_LOG_LEVEL=debug aether <flags> 2>&1 | while IFS= read -r l; do printf '%s %s\n' "$(date +%T.%3N)" "$l"; done`.
3. Common causes to check, in order:
   a. Two runs started too fast after each other: the previous Aether child is still shutting down, the SOCKS port or the identity file is still in use. Check that teardown waits for the child to exit (`child.wait()` with a 2 s timeout then kill) BEFORE the next run starts.
   b. The previous run's journal or TUN is not fully removed.
   c. Cooldown: Aether puts a just-failed endpoint on cooldown. Check whether rung 1 reuses a gateway that failed in the previous run.
   d. Rate limiting by Cloudflare because each run re-registers. Check the identity file persists across runs (it does according to the report, confirm in the bench).
4. Fix the root cause. Do not raise timeouts as a fix.
Verify: `zohald bench connect --runs 20 --label after-fix` gives ok >= 19.
Done when: at least 19 of 20 runs succeed, twice in a row.

### TASK 2.3 Measure a real baseline
1. `git worktree add ../zohal-baseline 8dc8a8a` (the commit before the speed work). Build it. Run the same bench there with `--label baseline` (use a bench binary built from the CURRENT code against the baseline engine only if the baseline has no bench; otherwise time connects with the timeline logging patched in as a minimal patch kept in `docs/perf/baseline.patch`).
2. Write real baseline p50/p95 and the success rate into `docs/PERF.md`. Delete every unmeasured number from older docs and the README.
Done when: `docs/PERF.md` has a baseline row measured on this machine and network with the date.

### TASK 2.4 Fix the verification honesty for TUN mode
1. Keep the existing SOCKS5 CONNECT check to 1.1.1.1:443. It is the PROXY-PATH check and must run BEFORE any route is changed. If it fails, no system change is made.
2. Add the TUN-PATH check: AFTER routes and DNS are applied, open a plain `tokio::net::TcpStream::connect(("1.1.1.1", 443))` with an unmarked normal socket and a 1500 ms timeout. In TUN mode on Linux this connection goes through the routing rules into the TUN. It must succeed. On failure: undo the system change, stop the candidate, move to the next rung.
3. Fetch `/cdn-cgi/trace` in a BACKGROUND task after "Connected" and fill `exit_ip`, `exit_loc`, `colo` when it arrives. Until it arrives these fields are `None` and the UI shows nothing for them.
4. Android and proxy scope: only the proxy-path check applies (state this in `docs/KNOWN_LIMITS.md`).
Done when: a unit test with a fake backend proves a failing TUN-path check triggers undo and the next rung, and the real Linux netns test shows both checks.

---

## 3. CONNECT SPEED PROGRAM

Method: measure, change ONE thing, measure again, keep only if the median improves by at least 5% or the failure rate drops. Otherwise revert. Record every attempt (kept or reverted) as a row in `docs/PERF.md`: change, before p50/p95, after p50/p95, kept/reverted.

Targets (all measured on Linux with the real Aether, same network, 20 runs each):
| Path | p50 | p95 |
|---|---|---|
| Hot standby ready (tap to Connected) | 0.5 s | 1.0 s |
| Warm (cached gateway, no standby) | 1.5 s | 3.0 s |
| Cold (no cache, fresh install, identity already registered) | 5 s | 8 s |
Success rate: at least 95 of 100 runs. Report real results; if a target is missed, say by how much and why.

### TASK 3.1 Timeline instrumentation (do this before any optimization)
1. Add `ConnectTimeline` in `zohal-engine` with monotonic `Instant` marks:
   `t_request` (command received), `t_settled`, `t_prepare_done`, `t_aether_spawned`, `t_aether_listening`, `t_candidate_validated` (rung result), `t_tun_created`, `t_routes_applied`, `t_proxy_path_ok`, `t_tun_path_ok`, `t_connected`, plus `rung`, `transport`, `used_cache`.
2. Emit it as one `tracing` event at INFO when a connect finishes (success or failure) and attach the last 20 timelines to the diagnostics export.
3. Convert marks to millisecond deltas in one function with unit tests.
Done when: after any connect, the log has one line with all deltas and a test asserts monotonic ordering.

### TASK 3.2 Aether startup forensics (find the 4 seconds)
1. Run Aether alone with the flags of rung 1 and rung 2. Capture timestamped output (see 2.2 step 2). Also capture network activity: `sudo timeout 20 tcpdump -i any -nn -tttt 'host 1.1.1.1 or port 443 or port 2408 or udp' -w /tmp/aether.pcap` while it starts, then `tcpdump -r /tmp/aether.pcap -nn -tttt | head -80`.
2. Build a table in `docs/AETHER_NOTES.md` with these rows and real timestamps relative to process start: process start, config loaded, identity loaded, any call to the registration or profile API (note the host and how long it took), scan start, first candidate found, data-plane check start/end, SOCKS port open.
3. Look for any wait of about 3 to 5 seconds with no network activity (a fixed timer) and any API call that takes long (identity check or profile refresh at startup).
4. For each environment variable in this list, read what it does in `aether --help` and `Docs/DOCS.en.md` at the pinned tag, then test its effect on the timeline one by one: `AETHER_MASQUE_STARTUP_SECS`, `AETHER_MASQUE_VALIDATE_SECS`, `AETHER_WG_VALIDATE_SECS`, `AETHER_PERF_PROFILE`, `AETHER_WG_ENDPOINT_COOLDOWN_SECS`, `AETHER_REPROVISION`, `AETHER_ROUTE_SNIFF_MS`. Never set a value you have not measured.
5. If the fixed wait or the identity check is inside Aether and no flag removes it: look at the source (`third_party/aether-src`, `grep -rn "startup\|validate\|reprovision\|profile" aether/src | head -50`). If a safe small patch skips the startup identity re-check when the identity was validated recently, write it as `patches/0002-skip-recent-identity-check.patch`, controlled by a new env var `ZOHAL_SKIP_IDENTITY_CHECK=1` which the engine sets only when its own record says the identity was validated in the last 24 hours. Build the patched Aether in CI. Keep the unpatched official binary as the fallback and make the engine choose by capability probe (`aether --help | grep`), never by assumption.
Done when: `docs/AETHER_NOTES.md` explains where each second of startup goes with measured numbers, and each env var is marked "helps / no effect / harmful".

### TASK 3.3 Fix rung 1 on empty cache
1. In `ladder.rs`, when the cache has no gateway for this network and transport, rung 1 must NOT pass `--quick-reconnect` or an `h2_proven_only` restriction. It must use a plain `--scan turbo` with no peer.
2. Add a unit test: empty cache gives rung 1 flags without cache options; non-empty cache gives `--peer <best gateway>`.
3. Log the winning rung per run in the bench.
Done when: bench `winning_rung` shows rung 1 or 2 winning on a cold run and the test passes.

### TASK 3.4 Racing (parallel candidates)
Why: serial rungs waste time. Race two candidates and keep the first that passes the proxy-path check.
Steps:
1. Re-run experiment E3 from the old spec: two Aether processes at once with separate ports and separate COPIES of the identity files. Record whether both work. If both work: race. If not: hedged start (start rung 2 after 1.2 s without killing rung 1).
2. Implement `CandidateSet` in the supervisor: spawn up to 2 candidates. Each gets its own temp config directory under the data dir (`run-<n>/`), seeded by copying the identity files, its own SOCKS port, its own HTTP port.
3. First candidate whose SOCKS port accepts AND passes the proxy-path check wins. Kill the loser: send SIGTERM, wait 200 ms, SIGKILL. Remove its temp directory. Copy back its `lastconn` result ONLY if it is the winner.
4. Race pairs: rung 1 vs rung 2 (h2+fragment vs h3). On rungs 3 and 4 also race two documented port variants of the same transport (Aether's scan already tries 443, 500, 1701, 4500, 4443, 8443, 8095): use `--peer <ip>:<port>` for the top cached gateway on two different ports.
5. Cancellation: if desired changes while racing, kill both immediately and clean up (no orphan, no temp dir left).
Verify: bench with `--label racing`. Property test with the fake backend: 1,000 random cancel points, no leaked process or temp directory.
Done when: p50 and p95 improved or the change is reverted and documented.

### TASK 3.5 Hot standby ("اتصال آنی")
Idea: keep Aether running with a validated tunnel but NO routing and NO system change. When the user taps connect, only the routes, DNS and the TUN-path check remain.
Rules (all required):
1. New setting `instant_connect` (bool, default true on desktop, default false on Android). Persian label: «اتصال آنی». Description: «یه اتصال آماده نگه می\u200cداره تا وقتی زدی، فوری وصل بشی.»
2. State `Standby` is internal. The UI still shows "disconnected". Nothing is routed. The standby Aether listens only on loopback random ports.
3. Standby starts: after the engine starts (if auto-connect off), after a disconnect, and when the UI becomes visible. It lives at most 10 minutes without a connect, then exits.
4. Kill the standby immediately on: network change (fingerprint change), settings change that affects the transport, low battery or battery saver (Linux: `/sys/class/power_supply/*/status` is "Discharging" and capacity below 20), engine shutdown, UI hidden for more than 60 s on Android.
5. On Android standby runs only while the UI is in the foreground and is stopped 60 seconds after the UI pauses.
6. When the user connects and a healthy standby exists (alive, SOCKS port open, last proxy-path check less than 60 s old): adopt it as the winning candidate, skip the Find Gateway stage.
7. Standby doubles as the gateway pool refresher: after it validates, harvest its `lastconn` (up to 8 gateways) into the cache (section 4, TASK 4.2).
8. Cost control: no keepalive tuning changes; accept Aether's own keepalives. Document the idle traffic cost measured over 10 minutes (bytes from the interface or process counters) in `docs/PERF.md`.
Verify: bench `--label standby` for tap-to-Connected. Test: a fake backend test proving the standby is never routed, is killed on network change, and is adopted exactly once.
Done when: tap-to-connected p50 <= 0.5 s on the bench, or the measured reason is documented.

### TASK 3.6 Pipeline the system work
1. While Aether is still searching, do these in parallel (they do not need Aether): pick the TUN subnet and rule numbers, create the TUN device and set its address and MTU (no routes yet), pre-resolve the physical default route.
2. After the candidate is validated: apply routes only (one batched call), DNS, then the TUN-path check.
3. On Linux use `ip -batch -` with all route and rule commands on stdin (one process instead of many). Journal ONE write-ahead record that lists all planned actions (one fsync) BEFORE the batch runs, then mark them applied. This keeps write-ahead safety with one fsync instead of one per action.
4. Write cache and rung memory files AFTER the state is "Connected" (background task), never before.
5. Verify the Aether binary hash once per engine start (cache by path, modified time and size), never per connect.
6. Replace every polling `sleep` in the connect path with event-driven waits: wait for the SOCKS port with a connect-retry loop starting at 5 ms and growing to 40 ms, together with watching Aether's output for its listening line; whichever comes first.
7. Reuse one HTTP agent for probes (do not build a new client per probe).
Verify: bench `--label pipeline`. Report Build Tunnel and Verify Path stage deltas before and after.
Done when: sum of system-work stages after Aether is ready is at most 150 ms p50 (measured), or the reason is documented.

### TASK 3.7 Network-change prewarm
When the default route or gateway changes (netlink on Linux, `NotifyIpInterfaceChange` on Windows, `NetworkCallback` on Android): debounce 800 ms, recompute the fingerprint, and if desired is up or `instant_connect` is on, start the standby for the new fingerprint immediately. The old standby is killed first.
Done when: a netns test that switches the physical interface shows a new standby within 2 s and no route leak.

---

## 4. RESILIENCE AND "UNDERGROUND" TECHNIQUES (APPLICABLE ONES ONLY)

What the community techniques are and what applies to Zohal (Aether = Cloudflare WARP client):
- Applicable in Zohal's engine: strategy learning per network, clean-gateway pools, port racing, fake-IP DNS, fragment parameter tuning, QUIC/TUN tuning experiments.
- Applicable only inside Aether (patch or contribute upstream, measured): QUIC congestion control, UDP batching, session resumption.
- Not applicable (needs your own server, so out of scope): Reality/XTLS, Hysteria2 server, TUIC server, ShadowTLS, NaiveProxy. Do not start these.

### TASK 4.1 Strategy learning (Thompson sampling) replaces fixed rung order
Goal: the engine learns which strategy works on THIS network and tries it first.
Definitions:
- An ARM is a tuple `(transport, noize, fragment_on, scan_mode, port_class)`. Keep at most 12 arms (the ladder rungs plus a few variants).
- Per network fingerprint and per arm store: `successes`, `failures`, `mean_time_ms` (EMA with alpha 0.3). Start every arm with a prior of Beta(1,1).
- Daily decay: multiply `successes` and `failures` by 0.98 per day since the last update, so old results fade.
Algorithm (pure function, deterministic when given a seed, unit-tested):
```
for each arm:
    p = sample Beta(successes + 1, failures + 1) using the seeded RNG
    expected_cost_ms = mean_time_ms if known else 6000
    score = p / (expected_cost_ms + 500)
order arms by score descending
exploration: with probability 0.10, swap the first arm with a random arm that has fewer than 5 trials
```
Rules: never drop the last-resort rungs; the final order always ends with the gool/WireGuard rungs; the learned order only reorders rungs 1 to 4. Persist in `rungs.json` (replace the old rung memory). Add a simulation test: three fake networks (UDP blocked, DPI on h3, open) with fixed success rates; after 200 simulated connects the learned first arm must be the best arm for each network in at least 90% of 50 seeded trials. Implement Beta sampling with two Gamma draws or a simple, tested approximation; do not add a new crate unless `rand_distr` is justified in DECISIONS.
Done when: the simulation test passes and the bench shows rung memory is loaded (`used_memory=true` in the timeline).

### TASK 4.2 Gateway pool (the "clean IP" technique, done politely)
1. Cache per fingerprint and per transport the best 8 gateways with `ip:port`, last RTT, last success, failure count, cooldown.
2. Harvest from three sources: the winning candidate's `lastconn`, the standby's `lastconn`, and (only while idle, on unmetered power-ok networks) a slow background validation of cached entries: at most 1 candidate per 20 seconds, never more than 10 per hour, stop immediately when the user connects.
3. Never run a wide scan in the background. The standby scan is the only discovery source.
4. Entry ordering for a connect: lowest recent RTT first, skip entries in cooldown.
Done when: unit tests cover insertion, eviction (max 8), cooldown, TTL 24 h, and corruption recovery (a corrupted `endpoints.json` is moved to `.corrupt` and a fresh file starts).

### TASK 4.3 Fake-IP DNS (virtual DNS) [VERIFY tun2proxy support]
Why it is a big win: no DNS round trip before the first connection, no DNS leak by design, and domain-based routing rules work for ALL flows including QUIC because the engine can map the fake IP back to the name.
Steps:
1. Check tun2proxy for a virtual DNS mode: `tun2proxy-bin --help | grep -i dns` and docs.rs for the library options. Record the exact option names and the default fake address pool in `docs/DECISIONS.md`.
2. IMPORTANT conflict: the old spec picks the TUN subnet from `198.18.0.0/30` first. Most virtual DNS implementations use `198.18.0.0/15` for fake addresses. Reorder the TUN subnet candidates to: `100.127.255.0/30`, `10.255.255.0/30`, `198.19.255.0/30`. Add a probe that rejects any subnet overlapping the fake pool.
3. Enable virtual DNS by default when verified. Set the system DNS to the TUN's own resolver address so applications ask tun2proxy, which answers instantly with fake IPs, while SOCKS CONNECT requests carry the real domain name to Aether (`socks5h` behaviour).
4. Keep the previous behavior as a fallback: setting `dns.mode` = `Tunnel` (real resolution through the tunnel). The engine switches to the fallback automatically if the virtual mode fails its self-test (resolve `cloudflare.com` and connect to the returned address within 2 seconds).
5. Known pitfall to handle: if the engine restarts, fake IPs that applications cached become invalid. On every engine start flush the system DNS cache where possible (`resolvectl flush-caches`) and keep the fake mapping stable by persisting it in the engine data directory (atomic file).
6. Domain routing: with the mapping known to the engine, give Aether the real domain (through SOCKS5 domain addressing) so `--routes` domain rules work for TCP and UDP flows.
Verify: netns test measuring `curl` first-byte time with and without virtual DNS (20 runs each), record in `docs/PERF.md`; leak test showing zero DNS packets on the physical interface.
Done when: it is faster or equal, no leak, and the fallback is proven by a test that forces the self-test to fail.

### TASK 4.4 Fragment tuning per network [VERIFY parameters]
1. Read `aether --help` for `--fragment`, `--fragment-size`, `--fragment-delay` and record their units and defaults.
2. Define a small grid of at most 6 combinations around the defaults.
3. Only when rungs using fragment keep failing on a fingerprint (3 failures in a row), test the grid combinations in the background with the standby mechanism (one at a time, 8 s deadline each), and store the first winner per fingerprint.
4. Use the stored values on later connects for that fingerprint.
Done when: unit tests cover the selection logic with a fake backend, and `docs/PERF.md` has one real before/after case, or a note saying no network available for the test.

### TASK 4.5 Aether fork experiments (each is a separate measured experiment; keep only winners)
Build a lab first: `tools/lab/netem.sh` creates a network namespace pair and applies `tc qdisc add dev <if> root netem delay 80ms 20ms loss 2%` (profiles: clean, lossy2, lossy5, highrtt). Run a throughput test through the tunnel in each profile using `iperf3` against a local server in the lab (loopback upstream, no Cloudflare needed for comparing configurations of the engine and TUN) and, separately, a real download through Aether when internet is available. Record in `docs/PERF.md`.
Candidate patches (apply as `patches/00NN-*.patch` on the Aether fork, build in CI, never replace the official binary unless the patch wins by at least 10% throughput or 20% lower connect time):
- E10: QUIC congestion control. Read Aether's quiche setup (`grep -rn "set_cc_algorithm\|CongestionControl" third_party/aether-src`). If it uses CUBIC or Reno, try BBR2 on lossy profiles. [VERIFY]
- E11: UDP socket buffers (`SO_RCVBUF`, `SO_SNDBUF` to 4 MB). Check `strace -c -f -p <aether pid>` for syscall counts first.
- E12: UDP GSO/GRO and `recvmmsg`/`sendmmsg` if quiche and the socket layer allow it. [VERIFY]
- E13: QUIC session resumption / 0-RTT for the MASQUE handshake. Check whether Aether stores tickets. If not and the patch is small, try it. [VERIFY]
- E14: TUN throughput: compare tun2proxy against hev-socks5-tunnel in the lab (same machine). Also test TUN offload (`IFF_VNET_HDR`) support in the TUN front end if available. Keep a front end only if it gives at least 20% more throughput at the same CPU.
Done when: each experiment has a row in `docs/PERF.md` with keep or revert. Zero unmeasured claims.

### TASK 4.6 Engine resource budget
Measure and record: `zohald` RSS idle and connected (`grep VmRSS /proc/<pid>/status`), CPU while idle over 60 s (`pidstat -p <pid> 5 12`), wakeups per second (`perf stat -e context-switches` or `pidstat -w`). Fix any timer firing more often than 1 Hz while idle. Budget: idle RSS at most 25 MB, idle wakeups at most 2 per second.
Done when: numbers are in `docs/PERF.md` and meet the budget or the reason is documented.

---

## 5. AUTO-UPDATE SYSTEM

### 5.1 Design summary (decisions are final)
- One signed manifest `latest.json` + `latest.json.minisig` published on every release. Clients fetch `https://github.com/arsamadineh/zohal-connect/releases/latest/download/latest.json`. This URL redirects to the newest normal release asset: one request, no API rate limit, works through a normal proxy.
- Trust root: an Ed25519 public key embedded in the binary (minisign format). Nothing is installed unless: manifest signature valid, asset listed in the manifest, SHA-256 matches, version is strictly newer than the running version.
- Downloads go through the local tunnel proxy when connected (the engine state exposes `local_http_proxy`), else directly. Resume supported. Never run unverified bytes.
- The user always has a manual path: «دانلود دستی» opens the release page in the browser.
- Platform apply methods:
  - **AppImage:** download next to the current AppImage, verify, atomic swap, keep `.prev`, relaunch with a watchdog that rolls back automatically if the new version does not start.
  - **Windows:** one UAC prompt, silent Inno Setup upgrade, relaunch.
  - **Linux deb/rpm:** one polkit prompt, package manager run from a transient systemd unit, relaunch.
  - **Android:** verified APK installed with PackageInstaller, auto reconnect after the update.
- After any update that restarts the app, if the user was connected, reconnect automatically.

### 5.2 Release asset names (fixed; the release workflow must produce exactly these)
```
latest.json                              latest.json.minisig      SHA256SUMS.txt
Zohal-<ver>-x86_64.AppImage              Zohal-<ver>-aarch64.AppImage
zohal_<ver>_amd64.deb                    zohal_<ver>_arm64.deb
zohal-<ver>-1.x86_64.rpm                 zohal-<ver>-1.aarch64.rpm
Zohal-Setup-<ver>-x64.exe
Zohal-<ver>-arm64-v8a.apk   Zohal-<ver>-armeabi-v7a.apk   Zohal-<ver>-x86_64.apk   Zohal-<ver>-universal.apk
```
`<ver>` has no leading `v` (the git tag has it: `v0.2.0`).

`latest.json` schema (schema version 1):
```json
{
  "schema": 1,
  "version": "0.2.0",
  "published_at": "2026-10-20T10:00:00Z",
  "min_supported": "0.1.0",
  "mandatory": false,
  "notes_fa": "متن فارسی تغییرات",
  "notes_en": "English notes",
  "assets": [
    {"os":"linux","kind":"appimage","arch":"x86_64","name":"Zohal-0.2.0-x86_64.AppImage",
     "url":"https://github.com/arsamadineh/zohal-connect/releases/download/v0.2.0/Zohal-0.2.0-x86_64.AppImage",
     "size":123456789,"sha256":"<64 hex>"}
  ]
}
```
Kinds: `appimage`, `deb`, `rpm`, `exe`, `apk`. The generator script `tools/make-manifest.py` builds this file from the real built assets (computing size and SHA-256 itself). It must fail if an expected asset is missing.

### 5.3 New crate `engine/crates/zohal-updater`
Dependencies (verify each with the 30-day rule): `semver`, `serde`, `serde_json`, `thiserror`, `sha2`, `minisign-verify`, `ureq` (use the SAME major version already used in the repo; the repo uses the `ureq::builder()` API which is ureq 2.x), `tracing`. Dev-dependencies only: `tiny_http`, `tempfile`.
Modules: `version.rs`, `manifest.rs`, `verify.rs`, `net.rs` (HTTP agent, proxy choice, download with resume), `state.rs` (state machine), `apply_appimage.rs`, `apply_windows.rs`, `apply_linux_pkg.rs`, `relaunch.rs`, `error.rs`, `lib.rs`. Android APK install is Kotlin; the crate only downloads and verifies.

#### 5.3.1 Pure functions (write these first, with tests). Reference code (compile it, fix small API differences by reading docs.rs):
```rust
// version.rs
use semver::Version;

pub fn parse_tag(tag: &str) -> Result<Version, semver::Error> {
    Version::parse(tag.trim().trim_start_matches('v'))
}

/// true only when `candidate` is strictly newer than `current`.
pub fn is_newer(current: &str, candidate: &str) -> bool {
    match (parse_tag(current), parse_tag(candidate)) {
        (Ok(c), Ok(n)) => n > c,
        _ => false,
    }
}
```
```rust
// verify.rs
use sha2::{Digest, Sha256};
use std::{fs::File, io::Read, path::Path};
use minisign_verify::{PublicKey, Signature};

#[derive(Debug, thiserror::Error)]
pub enum VerifyError {
    #[error("signature invalid")]
    BadSignature,
    #[error("hash mismatch")]
    HashMismatch,
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
}

/// pubkey_b64 is the base64 line of the minisign .pub file. [VERIFY exact API on docs.rs]
pub fn verify_manifest(pubkey_b64: &str, manifest: &[u8], sig_text: &str) -> Result<(), VerifyError> {
    let pk = PublicKey::from_base64(pubkey_b64).map_err(|_| VerifyError::BadSignature)?;
    let sig = Signature::decode(sig_text).map_err(|_| VerifyError::BadSignature)?;
    pk.verify(manifest, &sig, false).map_err(|_| VerifyError::BadSignature)
}

pub fn sha256_file(path: &Path) -> Result<String, VerifyError> {
    let mut file = File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buf = vec![0u8; 64 * 1024];
    loop {
        let n = file.read(&mut buf)?;
        if n == 0 { break; }
        hasher.update(&buf[..n]);
    }
    Ok(hex::encode(hasher.finalize()))
}
```
(`hex` crate or format each byte with `{:02x}`; prefer `format!` to avoid a dependency.)

```rust
// net.rs  (host allow-list for the FIRST url; redirects may go to github-owned hosts)
pub fn first_url_allowed(url: &str) -> bool {
    url.starts_with("https://github.com/arsamadineh/zohal-connect/releases/")
}
pub fn redirect_host_allowed(host: &str) -> bool {
    host == "github.com"
        || host.ends_with(".githubusercontent.com")
}
```
Tests required: version ordering (`0.1.4 < 0.2.0`, `0.2.0-beta.1 < 0.2.0`, equal is not newer, garbage returns false); manifest parse with unknown extra fields (ignored) and missing required fields (error); signature good/bad/modified-manifest; hash good/bad; asset selection by `(os, arch, kind)`; allow-list accepts the real URL and rejects `http://`, other repos and look-alike hosts.

#### 5.3.2 Download with resume (net.rs)
Behavior:
1. Destination `<dir>/<name>.part` and `<name>.part.meta` (JSON: `url`, `expected_size`, `etag`).
2. If `.part` exists and meta matches: send `Range: bytes=<len>-` (and `If-Range: <etag>` when known). If the server answers 206 append; if 200 start over; if 416 treat as complete and verify.
3. Read in 64 KB chunks. Call the progress callback at most 5 times per second with `(received, total, speed_bps_ema, eta_secs)`.
4. Stall: no bytes for 20 s means retry. Retries: 4 attempts with waits 1, 2, 4, 8 seconds. Each attempt resumes from the current length.
5. Disk space check before starting: need at least `size * 1.2` free in the target directory (use `statvfs` via the `nix` crate on Unix; `GetDiskFreeSpaceExW` through the `windows` crate on Windows). Failure gives `NoSpace { needed_mb }`.
6. At the end: size must equal `expected_size`, then SHA-256 must equal the manifest value, then rename `.part` to final name. On mismatch delete the file and report `HashMismatch`.
7. Proxy: when `proxy: Option<String>` is `Some("http://127.0.0.1:<port>")` build the agent with that proxy (read docs.rs for the exact ureq 2.x call). Else direct.
8. Only one updater runs at a time: take an exclusive file lock on `<dir>/updater.lock`.
9. Keep at most one previous download in the directory; delete others after a successful update.

#### 5.3.3 State machine (state.rs) exposed to Dart through the bridge
```rust
pub enum UpdateState {
    Idle,
    Checking,
    UpToDate { checked_at_unix: i64 },
    Available { version: String, notes_fa: String, notes_en: String, size_bytes: u64, mandatory: bool },
    Downloading { received: u64, total: u64, speed_bps: u64, eta_secs: Option<u32> },
    Verifying,
    ReadyToInstall { version: String },
    Installing { needs_reconnect: bool },
    Restarting,
    Failed { code: UpdateErrorCode, can_retry: bool, manual_url: String },
}
```
Error codes (stable, used by the UI copy): `U100` network, `U110` manifest or signature invalid, `U120` no asset for this platform, `U130` download failed, `U140` hash mismatch, `U150` no disk space, `U160` permission denied (elevation or Android install permission), `U170` install failed, `U180` rolled back.
Transitions: `Idle -> Checking -> (UpToDate | Available | Failed)`, `Available -> Downloading -> Verifying -> ReadyToInstall -> Installing -> Restarting`, any state -> `Failed`, `Failed -> Checking` on retry. No other transitions. Test each allowed and each forbidden transition.

#### 5.3.4 Check schedule and rules
- First check 15 s after the UI starts (random jitter 0 to 10 s), then every 6 hours (plus or minus 30 min), on manual request, and ONCE after each successful connect if the last check is older than 24 hours (a filtered user can only reach GitHub when connected).
- Send `If-None-Match` with the stored ETag; a 304 keeps the current state.
- Version must be strictly greater than the running version. A version the user skipped (`skipped_version`) is not offered again unless `mandatory` is true.
- If `latest.json` fetch fails, fall back once to `https://api.github.com/repos/arsamadineh/zohal-connect/releases/latest`, find the assets named `latest.json` and `latest.json.minisig` by name, download those two, and continue the same verification. If this also fails: silent for automatic checks, show the friendly error for manual checks.
- Never check more than once per 10 minutes automatically.

### 5.4 Settings for updates (stored in the UI-owned `app_prefs.json`, atomic write)
`update.auto_check` (default true), `update.auto_download` (default true on desktop, true on Android only when the network is unmetered), `update.notify` (default true), `update.skipped_version` (string), `update.last_checked_unix`, `update.etag`, `pending_reconnect` (bool, set before an update restart if the user was connected).

### 5.5 Platform: AppImage (Linux)
Detect: the environment variable `APPIMAGE` is set (path of the running AppImage) and the file exists.

Build requirements (release workflow): build an AppDir containing the Flutter bundle, `zohald`, `aether`, `libnotify` and the `.desktop` file; set `AppRun` to export `ZOHAL_APPDIR=$APPDIR` and exec the UI. Use the newest `appimagetool` (verify its SHA-256 from the release page). Produce `Zohal-<ver>-x86_64.AppImage`.

Update steps (`apply_appimage.rs`, run in the UI process, no root):
1. `cur = canonicalize($APPIMAGE)`. Check the directory is writable (`access(W_OK)`). If NOT writable: state `Failed{U160, can_retry:false}` with the friendly "manual download" message. Do not attempt another location.
2. Download directly to `<dir>/.<name>.new` using 5.3.2 (same directory means same filesystem, so rename is atomic). Verify. `chmod 0755`.
3. Swap atomically. Preferred: `renameat2(cur, new, RENAME_EXCHANGE)` (Linux; `nix::fcntl::renameat2` [VERIFY], else `libc::syscall(SYS_renameat2, ...)`), then rename the now-old file at the `.new` path to `<name>.prev` (replace any older `.prev`). Fallback when exchange is not supported: rename `cur` to `.prev` then `new` to `cur`.
4. Spawn the watchdog, DETACHED, before the old process exits. Use the `.prev` file (the OLD version) in watchdog mode:
   `<name>.prev --update-watchdog --wait-pid <old_pid> --cur <cur> --prev <prev> --marker <runtime>/zohal/started-<newver> --timeout-secs 25 --new-version <newver>`
   Clean the child environment first: remove `APPIMAGE`, `APPDIR`, `ARGV0`, `OWD`, `LD_LIBRARY_PATH`, `LD_PRELOAD`, `PYTHONHOME`, `GIO_MODULE_DIR`, `GDK_PIXBUF_MODULE_FILE`, `QT_PLUGIN_PATH`. Set `APPIMAGE_EXTRACT_AND_RUN=1` if `/dev/fuse` is missing or `libfuse.so.2` cannot be found. Use `setsid` through `pre_exec` and null stdio.
5. The old UI saves `pending_reconnect` if connected, then exits with code 0.
6. Watchdog logic (runs in the OLD AppImage because it contains this code):
   a. Wait until `wait-pid` is gone (poll `/proc/<pid>` every 100 ms, max 15 s).
   b. Start `<cur> --post-update` detached with a clean environment.
   c. Wait up to `timeout-secs` for the marker file. The NEW UI creates the marker after its first frame is shown and the engine socket answered hello.
   d. If the marker appears: success. Delete nothing (keep `.prev` as the rollback copy). Exit.
   e. If the new process exits early or the marker never appears: rollback: `rename(prev, cur)` (replace), write `<state>/update_result.json` `{"status":"rolled_back","bad_version":"<v>"}`, start `<cur>` and exit. The UI shows copy `update.rolled_back` once and never offers that version again.
7. The first launch of a new version with the `--post-update` flag shows the success copy and clears `pending_reconnect` by reconnecting.
8. Single instance interplay: the single-instance lock must be skipped for a process started with `--update-watchdog`, and a normal instance started during `--post-update` must wait for the old PID to exit (the watchdog already waits, so no conflict).
9. Version skew with the engine after an AppImage update:
   - User-mode engine (`zohald user`, same uid): at UI start compare the engine's hello `server` version with the UI's. If different: if the engine is Idle, ask it to exit (add the typed command `shutdown`, allowed ONLY on the user-mode socket and only when phase is Idle or Failed), then spawn the new one. If it is connected, keep it connected and show «نسخه\u200cی موتور قدیمیه؛ بعد از قطع اتصال خودکار تازه می\u200cشه.» and update the engine after the next disconnect.
   - Root service installed from an older AppImage (the pkexec staged install from the last commit): the UI detects version skew and runs the SAME staged install flow once to refresh `/usr/lib/zohal/` (one polkit prompt), explained by copy `update.service_refresh`. Never leave the user with a new UI and an old root service silently.
Tests: unit-test the swap function in a temp dir with a fake "AppImage" shell script (success path, non-writable directory, rename failure, rollback via a fake new version that exits 1 immediately, rollback when the marker never appears). The watchdog must be testable by giving it short timeouts.

### 5.6 Platform: Windows
Build requirements: Inno Setup script must have a fixed `AppId` GUID (so upgrades replace in place), `CloseApplications=yes`, `RestartApplications=no`, `UsePreviousAppDir=yes`, and a `[Code]` step before copying files that stops the service `ZohalEngine` (`sc.exe stop ZohalEngine`) and waits until it is stopped (max 15 s), and a `[Run]` step that starts the service again. The service's stop handler already runs cleanup (journal undo).

Update steps:
1. UI downloads and verifies into `%LOCALAPPDATA%\Zohal\update\`.
2. The UI copies `zohald.exe` to `%TEMP%\zohal-relaunch-<pid>.exe` and starts it detached: `relaunch --wait-pid <pid> --target-version <v> --exe "<ui exe>" --timeout-secs 240`. (A copy is needed so the installer can replace the original.)
3. The UI saves `pending_reconnect`, then requests elevation through a bridge function `elevate_and_run(exe, args)` implemented with `ShellExecuteExW` and verb `runas` (Rust `windows` crate): `"<Program Files>\Zohal\zohald.exe" apply-update --file "<downloaded installer>" --manifest "<latest.json>" --sig "<latest.json.minisig>"`. Then the UI exits.
4. `zohald apply-update` (elevated) does, in order: copy the three files into `%ProgramData%\Zohal\update\` (admin-writable only; open source files without following reparse points), verify signature, find the asset by file name, check size and SHA-256 and that the version is newer than the installed one, and only then run `<installer> /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /LOG=<ProgramData>\Zohal\update\install.log` detached (flags `DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP | CREATE_BREAKAWAY_FROM_JOB`). The helper exits immediately.
5. If the user cancels the UAC prompt: `U160`, copy `update.elevation_denied`, the old version keeps running (the UI had not exited yet: do NOT exit the UI before the elevation call returns success).
6. The relauncher (user context) waits for the old PID to exit, then polls until `zohald.exe --version` in the install directory equals the target AND the service is running (Service Control API), up to the timeout. Then it starts the UI. On timeout it writes `%LOCALAPPDATA%\Zohal\update_result.json` `{"status":"failed"}` and exits; the next normal UI start shows `update.generic_fail` with the manual download button.
7. The new UI starts, sees `pending_reconnect`, and sets `desired=up`.
Tests: unit-test argument building, the verify steps, and a CI job on `windows-latest` that silently installs a fixture installer `0.0.1`, then runs the apply-update path against a fixture `0.0.2` installer signed with the TEST key, then asserts the installed version, service running, adapter present, no leftover temp copies.

### 5.7 Platform: Linux deb and rpm
Detect: not AppImage and (`/var/lib/dpkg/info/zohal.list` exists => deb; `rpm -q zohal` exit 0 => rpm). Otherwise (tarball install): manual update only (show the download page button).
Steps:
1. UI downloads and verifies into `$XDG_CACHE_HOME/zohal/update/`.
2. UI starts the relauncher detached (same `relaunch` subcommand as Windows, copied to `/tmp`).
3. UI runs `pkexec /usr/lib/zohal/zohald apply-update --file <deb or rpm> --manifest <latest.json> --sig <latest.json.minisig>` and waits for the pkexec exit code. Ship a polkit policy `app.zohal.update.policy` with action id `app.zohal.update`, `org.freedesktop.policykit.exec.path` = `/usr/lib/zohal/zohald`, `allow_active` = `auth_admin_keep`, message in Persian: «برای به\u200cروزرسانی زحل، رمز مدیر سیستم لازمه.»
4. `zohald apply-update` as root: open each input with `O_NOFOLLOW`, require regular files, owned by the pkexec caller (`PKEXEC_UID`), size at most 400 MB; copy to `/var/lib/zohal/update/` (mode 0700); verify signature, hash, newer version; then run the package manager from a TRANSIENT UNIT so it is not inside `zohald.service`'s control group (otherwise the package's restart of the service would kill the install):
   - deb: `systemd-run --collect --unit=zohal-update --setenv=DEBIAN_FRONTEND=noninteractive apt-get install -y /var/lib/zohal/update/<file>.deb`
   - rpm: use the first available of `dnf install -y`, `zypper --non-interactive install --allow-unsigned-rpm`, `rpm -U` on the file. Detect with `which` (absolute path check), never through a shell.
   Use `--no-block`; the helper exits right after starting the unit.
5. The package scripts (`postinst`/`%post`) must `systemctl try-restart zohald.service`.
6. The relauncher waits until `/usr/lib/zohal/zohald --version` equals the target and `systemctl is-active zohald` is `active`, then starts the new UI. Timeout 240 s.
7. If pkexec is missing or the user cancels: `U160`, nothing changed, offer manual download.
Tests: unit-test the detection, the asset choice, input validation (symlink rejected, wrong owner rejected, oversize rejected), and a container-based CI test (Ubuntu and Fedora containers with systemd are heavy; if not possible in CI, mark NOT RUN and add a manual QA step).

### 5.8 Platform: Android
1. Rust (in the UI process) downloads and verifies the APK that matches `Build.SUPPORTED_ABIS[0]` (fall back to `universal`) into `getCacheDir()/update/`, preferring the local tunnel proxy when connected. Remember: the whole app package is excluded from the VPN, so direct traffic does NOT go through the tunnel; use the local HTTP proxy port from the engine state when connected.
2. Kotlin `UpdateInstaller` (MethodChannel `zohal/update`, method `installApk(path)`):
   - If `!packageManager.canRequestPackageInstalls()`: open `Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES` with the package URI and return `needs_permission`. The UI shows copy `update.android_perm`, and continues when the user comes back.
   - Create a `PackageInstaller` session (`MODE_FULL_INSTALL`), on API 31+ call `setRequireUserAction(USER_ACTION_NOT_REQUIRED)`, write the APK stream, `commit` with an `IntentSender` to a `BroadcastReceiver` (`UpdateStatusReceiver`, exported=false, `PendingIntent.FLAG_MUTABLE` is required for session status intents on API 31+; read the current docs and follow them).
   - Handle `STATUS_PENDING_USER_ACTION` by starting the provided confirmation intent; handle `STATUS_SUCCESS`, `STATUS_FAILURE*` by sending the code back to Dart.
3. Declare `REQUEST_INSTALL_PACKAGES`. A `BroadcastReceiver` for `ACTION_MY_PACKAGE_REPLACED` (exported=true as required for system broadcasts, filter only that action): if `pending_reconnect` is set in SharedPreferences and VPN consent exists (`VpnService.prepare` returns null), start `ZohalVpnService` with the connect action, clear the flag, and post a notification with copy `update.success`.
4. Android cannot downgrade; never offer a lower version.
5. The new APK must be signed with the same key. Document this in `docs/RELEASING.md`.
Tests: unit-test ABI selection in Kotlin; instrumented test on the emulator only if it works without a real installer UI (otherwise NOT RUN and manual QA).

### 5.9 The relauncher (`zohald relaunch`) specification
Arguments: `--wait-pid <u32> --target-version <semver> --exe <path> --timeout-secs <u32> [--arg <x>]...`.
Loop: poll every 250 ms. Phase 1: wait for `wait-pid` to disappear. Phase 2: wait until the installed version equals `target-version` (platform check as above). Phase 3: spawn `--exe` detached with the original user's environment (it was started by the UI so the environment is inherited), then exit 0. On timeout write the failure file and exit 1. It never touches system settings.

### 5.10 UI for updates (all in the app theme: flat, sharp, hairlines, no shadows, accent only)
Components:
1. **Update banner** on the main screen, between the header and the control, 40 dp high, flat, 1 dp hairline bottom, text in `label` style, accent text for the action. Appears only in state `Available`, `Downloading`, `ReadyToInstall`, `Failed` (after a manual attempt). Height animates 0 to 40 dp with spring gentle; text cross-fades. Tapping opens the update sheet.
2. **Toast** (top, 48 dp, flat, hairline border, auto dismiss after 6 s, slide down with ease standard) when a new version is found while the app is in the foreground: copy `update.banner`, action `update.btn_update_now`. Only once per version.
3. **Update sheet** (same bottom sheet / side panel component as the mode sheet). Content in order: title `update.available_title` with the version (Persian digits); notes (`notes_fa` shown if the app language is Persian, rendered as plain text, markdown symbols removed, at most 8 lines then scroll, direction auto-detected per paragraph); size; actions `update.btn_update_now`, `update.btn_later`, `update.btn_skip`.
4. **Progress**: a flat track 4 dp high (hairline color) with an accent fill that animates with spring snappy (retargets, never jumps backwards), percent in Persian digits, speed, ETA. Under it a one-line status in `body` style from the copy bank. The sheet cannot be dismissed by dragging while `Installing`, but «بعداً» is available during `Downloading` (download continues in the background and the banner shows progress).
5. **Settings**: group «به\u200cروزرسانی»: row `update.settings_check` (shows last check time and a small spinner while checking), toggle `update.settings_auto_check`, toggle `update.settings_auto_download`, toggle `update.settings_notify`, row «دانلود دستی» (opens the releases page), row showing current version. About screen: version and a «بررسی به\u200cروزرسانی» button.
6. **Manual updates**: always available: «بررسی به\u200cروزرسانی», «دانلود دستی», and «رد کردن این نسخه». Every `Failed` state shows `update.btn_retry` and `update.btn_manual`.
7. If connected during an update, show copy `update.installing_connected` right under the progress bar before elevation or install begins.
8. Accessibility: progress has a semantics value; all actions are focusable and work with keyboard (Enter, Escape).

Native notifications (an extra, never required; the in-app UI must work without them):
- Desktop: package `local_notifier` [VERIFY it supports Windows and Linux in the current version]. Linux needs `libnotify`; add it to deb/rpm dependencies and bundle it in the AppImage. If initialization fails, log once and continue silently.
- Android: Kotlin `NotificationManagerCompat`, channel `zohal_update` (importance DEFAULT for "available", LOW for progress with `setProgress(100, p, false)`), triggered from Dart over the MethodChannel `zohal/notify`.
- Rules: at most one "available" notification per version; progress notification only on Android and only while downloading; a "done" notification only when the app was not in the foreground; never notify when `update.notify` is false; never notify while the app window is focused.

### 5.11 Bridge API (flutter_rust_bridge)
Expose in `zohal-bridge`: `update_check(manual: bool)`, `update_download()`, `update_apply()`, `update_cancel()`, `update_skip_version(v)`, `update_state_stream() -> Stream<UpdateState>`, `elevate_and_run(exe, args)` (Windows only), `open_url(url)` (or use `url_launcher`). Dart side: one Riverpod `StateNotifier` (`UpdateController`) wrapping the stream and holding the prefs; widgets read it with `select`.

### 5.12 Update tests (all required)
Create a local fake release server in tests (`tiny_http`) that serves `latest.json`, `latest.json.minisig`, and fixture assets signed with a TEST minisign key stored in `engine/crates/zohal-updater/tests/fixtures/` (test key only; the production public key is separate, see 7.1). Cases: normal update; 304 not modified; manifest tampered; signature from another key; hash mismatch; truncated download then resume completes; server ignores Range (200) then full restart; stall then retry; disk full simulation (inject a tiny free-space function); redirect to a disallowed host rejected; version equal or lower ignored; skipped version hidden; mandatory not hidden; GitHub API fallback; offline gives `U100` and no crash; two updaters at once (second blocked by lock). AppImage swap and rollback tests as in 5.5. A UI test (Dart) renders every `UpdateState` and asserts the exact copy strings.

---

## 6. COPY BANK AND TONE (use exactly; `\u200c` is the half-space escape)

### 6.1 Tone guide
Friendly, short, second person informal ("تو"), the app speaks as "من" only in update and progress messages. Say what is happening and what the user should do. No blame, no jargon, no more than one exclamation mark per screen, no emoji, no dashes. Numbers go through the Persian digit helper. In source code, use the escape for every half-space. If a half-space escape is missing, `tools/lint-persian.sh` must fail.

### 6.2 Update strings (key = text)
```
update.checking            دارم نگاه می\u200cکنم نسخه\u200cی جدیدی هست یا نه…
update.up_to_date          همین الان آخرین نسخه رو داری.
update.available_title     نسخه\u200cی جدید زحل
update.banner              نسخه\u200cی {v} رسیده؛ می\u200cخوای به\u200cروزش کنی؟
update.btn_update_now      به\u200cروزرسانی حالا
update.btn_later           بعداً
update.btn_skip            رد کردن این نسخه
update.btn_manual          دانلود دستی
update.btn_retry           تلاش دوباره
update.btn_connect_retry   وصل شو و دوباره امتحان کن
update.downloading         در حال دانلود؛ یه کم صبر کن
update.download_detail     {p}٪ · {speed} · حدود {eta} مونده
update.verifying           دارم مطمئن می\u200cشم فایل سالمه…
update.ready               آماده\u200cی نصبه.
update.installing_connected  نگران نباش، یه کم قطع می\u200cشی و دوباره وصل می\u200cشی.
update.installing_idle     در حال نصب؛ چند لحظه\u200cی دیگه تموم می\u200cشه.
update.restarting          زحل داره دوباره باز می\u200cشه…
update.success             به\u200cروزرسانی انجام شد؛ نسخه\u200cی {v} آماده\u200cست.
update.generic_fail        نشد به\u200cروز کنم. نگران نباش، نسخه\u200cی قبلی سالمه و کار می\u200cکنه.
update.net_fail            اینترنت آزاد نیست؛ اول وصل شو و دوباره امتحان کن.
update.no_space            جای خالی کافی نیست؛ حدود {n} مگابایت آزاد کن.
update.bad_file            فایل دانلود\u200cشده سالم نبود و نصبش نکردم. دوباره امتحان کن.
update.bad_signature       امضای این به\u200cروزرسانی معتبر نبود، برای همین نصبش نکردم.
update.android_perm        برای نصب، اجازه\u200cی «نصب برنامه» رو به زحل بده.
update.elevation_denied    بدون تأیید دسترسی مدیر نمی\u200cشه نصب کرد. اگه خواستی دوباره امتحان کن.
update.rolled_back         نسخه\u200cی جدید درست باز نشد، برای همین برگشتم به نسخه\u200cی قبلی.
update.service_refresh     سرویس زحل هم باید تازه بشه؛ یه بار رمز مدیر رو وارد کن.
update.settings_group      به\u200cروزرسانی
update.settings_check      بررسی به\u200cروزرسانی
update.settings_auto_check بررسی خودکار به\u200cروزرسانی
update.settings_auto_download  دانلود خودکار
update.settings_wifi_only  دانلود فقط با وای\u200cفای
update.settings_notify     اعلان به\u200cروزرسانی
update.last_checked        آخرین بررسی: {t}
update.notif_title         زحل
update.notif_available     نسخه\u200cی {v} آماده\u200cست.
update.notif_downloading   در حال دانلود به\u200cروزرسانی
update.notif_done          به\u200cروزرسانی نصب شد.
```
Error code to copy mapping: `U100 -> update.net_fail`, `U110 -> update.bad_signature`, `U120 -> update.generic_fail`, `U130 -> update.generic_fail`, `U140 -> update.bad_file`, `U150 -> update.no_space`, `U160 -> update.elevation_denied` (desktop) or `update.android_perm` (Android), `U170 -> update.generic_fail`, `U180 -> update.rolled_back`.
Relative time for `{t}`: `چند لحظه پیش`, `{n} دقیقه پیش`, `{n} ساعت پیش`, `{n} روز پیش` (Persian digits).

### 6.3 Friendly pack for the rest of the app (apply everywhere; replace the old formal strings)
States: idle `وصل نیستی`; preparing `دارم آماده می\u200cشم`; connecting `دارم وصل می\u200cشم`; connected `وصلی`; reconnecting `دارم دوباره وصل می\u200cشم`; disconnecting `دارم قطع می\u200cکنم`; failed `وصل نشد`.
Hints: tap to connect (touch) `برای وصل شدن بزن`; (desktop) `برای وصل شدن کلیک کن`; cancel `برای لغو دوباره بزن`.
Toast after changing the method: `روش اتصال عوض شد؛ دوباره وصل می\u200cشم`.
Errors (title, hint):
```
E100  اینترنت وصل نیست                          وای\u200cفای یا دیتا رو چک کن.
E110  ساعت دستگاهت اشتباهه                      تاریخ و ساعت رو روی حالت خودکار بذار.
E120  هیچ روشی جواب نداد                        چند دقیقه دیگه دوباره امتحان کن یا روش اتصال رو دستی انتخاب کن.
E130  حساب دستگاه تازه شد                       دارم دوباره وصل می\u200cشم.
E140  ثبت دستگاه نشد                            یه شبکه\u200cی دیگه امتحان کن؛ ثبت فقط یک بار لازمه.
E200  سرویس زحل در دسترس نیست                   سرویس رو راه\u200cاندازی کن یا دوباره نصبش کن.
E210  رابط شبکه ساخته نشد                       شاید آنتی\u200cویروس یا دیوار آتش جلوش رو گرفته.
E220  مجوز VPN داده نشد                         مجوز رو توی تنظیمات تأیید کن.
E230  یه برنامه\u200cی دیگه اتصال رو قطع کرد       برای وصل شدن دوباره بزن.
E250  نسخه\u200cی برنامه و سرویس به هم نمی\u200cخوره  برنامه رو به\u200cروز کن یا دوباره نصب کن.
E300  یه برنامه\u200cی دیگه تنظیمات رو عوض کرده    برنامه\u200cهای پراکسی یا VPN رو چک کن.
E400  هسته\u200cی اتصال متوقف شد                   خودش دوباره راه می\u200cافته.
E900  یه خطای ناشناخته پیش اومد                  گزارش رو کپی کن و دوباره امتحان کن.
```
The engine sends only error codes. All Persian copy lives in `app/lib/l10n/strings_fa.dart` (single source of truth). Remove Persian strings from Rust except log lines that are never shown to users.
Instant connect: label `اتصال آنی`, description `یه اتصال آماده نگه می\u200cداره تا وقتی زدی، فوری وصل بشی.`
Scope banner: keep the existing two labels.

---

## 7. RELEASE PIPELINE AND HUMAN STEPS

### 7.1 Signing key (HUMAN does this once, on their own machine)
Write `docs/RELEASING.md` with these exact steps for the human:
1. Install minisign (`sudo apt install minisign` or from the project page).
2. `minisign -G -p zohal-update.pub -s zohal-update.key` and choose a strong password. Back the secret key up offline. Losing it means existing installs can never trust a new key.
3. Copy the public key line (the second line, starting with `RW`) into `engine/crates/zohal-updater/src/pubkey.txt` and commit it.
4. In GitHub: Settings, Secrets and variables, Actions: add `MINISIGN_SECRET_KEY` (the whole secret key file content) and `MINISIGN_PASSWORD`.
5. Publish every release as a NORMAL release. Do not tick "pre-release", or `releases/latest/download/...` will not find it.
6. Android: keep the SAME release keystore forever (store it offline and as secrets); a different key makes updates impossible.
The agent MUST NOT generate or see the production secret key. The agent generates only a TEST key for tests.
`build.rs` in `zohal-updater` must fail release builds (`--release` or env `ZOHAL_RELEASE=1`) if `pubkey.txt` equals the test key, with a clear message.

### 7.2 Workflow changes (`.github/workflows/release.yml`)
On tag `v*`: build all artifacts with the fixed names in 5.2; run `tools/make-manifest.py` over the built artifacts; sign: `printf '%s' "$MINISIGN_PASSWORD" | minisign -S -s <(printf '%s' "$MINISIGN_SECRET_KEY") -m latest.json` [VERIFY how minisign reads the password non-interactively; if it cannot, use `rsign2` installed with `cargo install rsign2` and its `--password-file`]; verify the signature again in the workflow with the committed public key; create a NORMAL GitHub release with all files plus `SHA256SUMS.txt`. The workflow fails if any expected asset is missing.

### 7.3 Versioning
Version lives in ONE place (`engine/Cargo.toml` workspace version) and is injected into the Flutter build (`--dart-define=ZOHAL_VERSION=...`), the Inno script, nfpm, and Android `versionName`/`versionCode` (derive `versionCode` from major*10000+minor*100+patch). A CI step checks all of them are equal.

---

## 8. PHASE ORDER AND GATES

Order (do not reorder):
1. Section 1.4 tooling (`check-all.sh` and the two lint scripts). Gate: `tools/check-all.sh` passes.
2. Tasks 2.1 to 2.4 (audit). Gate: bench honest, at least 19 of 20 succeed twice, baseline measured, TUN-path check proven.
3. Tasks 3.1 to 3.7 (speed). Gate: every task has a `docs/PERF.md` row; targets met or the gap explained with data.
4. Tasks 4.1 to 4.6 (resilience). Gate: simulation, pool, fake-IP, lab results recorded.
5. Section 5.3 core crate with tests. Gate: all unit tests of 5.3.1 to 5.3.4 pass.
6. Release pipeline (7.1 to 7.3) with a TEST key dry run on a fork or a draft tag. Gate: manifest and signature produced and verified in CI.
7. AppImage apply (5.5) with watchdog and rollback tests. Gate: rollback tests pass.
8. Windows apply (5.6), Linux packages apply (5.7). Gate: CI silent upgrade test (Windows), unit tests (both).
9. Android apply (5.8).
10. UI, copy, notifications (5.10, section 6). Gate: all `UpdateState` widget tests, goldens for banner/sheet/progress in light and dark, persian lint passes.
11. Final: update `README.md` (keep the human tone), write `docs/UPDATES.md` (how it works and how to release), `docs/PERF.md` (all numbers), `docs/KNOWN_LIMITS.md`, `docs/QA_MANUAL.md` additions.

### 8.1 Manual QA additions (write into `docs/QA_MANUAL.md`, the human runs them)
- AppImage: install version A, publish B to a test repo or local server, update, confirm restart into B, confirm reconnect, then break B on purpose and confirm automatic rollback to A.
- Windows: update while connected, confirm one UAC prompt, confirm the tunnel returns and no stray adapters or rules remain.
- Linux deb and rpm: update on Ubuntu and Fedora, confirm one polkit prompt and that the service restarts.
- Android: sideload A, update to B on a low-end phone, confirm the install permission flow, the reconnect after update, and the notification.
- Offline and blocked-GitHub behavior: confirm friendly messages and that the manual button works.
- Tamper test: change one byte of a release asset and confirm it is refused with the bad-file message.

### 8.2 Final report format (last message, at most 60 lines)
1. What was done per task id, one line each.
2. Table of measured numbers (baseline, each kept change, final) copied from `docs/PERF.md`.
3. Which gates passed, which are `NOT RUN` and why.
4. Known limits.
5. What the human must do (signing key steps, secrets, first manual install, QA steps).
Do not claim zero bugs. Say what was verified and what was not.

END. Begin with section 1.4, then task 2.1. Do not skip gates. Do not ask questions.