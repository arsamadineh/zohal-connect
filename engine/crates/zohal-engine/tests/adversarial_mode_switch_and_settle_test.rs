use std::sync::atomic::{AtomicBool, AtomicU64, AtomicUsize, Ordering};
use std::sync::Arc;
use std::time::Duration;
use tempfile::tempdir;
use tokio::time::sleep;

use zohal_engine::backend::{BackendError, CandidateHandle, PathTrace, TunnelBackend};
use zohal_engine::cache::CacheManager;
use zohal_engine::journal::Journal;
use zohal_engine::ladder::RungConfig;
use zohal_engine::log_ring::LogRingBuffer;
use zohal_engine::supervisor::Supervisor;
use zohal_proto::settings::Settings;
use zohal_proto::types::{
    ConnectionMode, CustomNodeConfig, DesiredIntent, DesiredState, Phase, Transport,
};

/// An instrumented tracking backend that records candidate start, verify, and stop events with strict timestamps.
#[derive(Clone)]
struct TrackingBackend {
    next_id: Arc<AtomicU64>,
    active_processes: Arc<AtomicUsize>,
    max_concurrent: Arc<AtomicUsize>,
    history: Arc<parking_lot::Mutex<Vec<TrackingEvent>>>,
    start_delay: Duration,
    fail_verify: Arc<AtomicBool>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
enum TrackingEvent {
    Start { id: u64, transport: Transport },
    Verify { id: u64 },
    ApplyTunnel { id: u64 },
    TeardownTunnel,
    Stop { id: u64 },
}

impl TrackingBackend {
    fn new(delay: Duration) -> Self {
        Self {
            next_id: Arc::new(AtomicU64::new(100)),
            active_processes: Arc::new(AtomicUsize::new(0)),
            max_concurrent: Arc::new(AtomicUsize::new(0)),
            history: Arc::new(parking_lot::Mutex::new(Vec::new())),
            start_delay: delay,
            fail_verify: Arc::new(AtomicBool::new(false)),
        }
    }
}

impl TunnelBackend for TrackingBackend {
    fn start_candidate<'a>(
        &'a self,
        rung: &'a RungConfig,
        endpoint: Option<&'a str>,
    ) -> std::pin::Pin<
        Box<dyn std::future::Future<Output = Result<CandidateHandle, BackendError>> + Send + 'a>,
    > {
        Box::pin(async move {
            if self.start_delay > Duration::ZERO {
                sleep(self.start_delay).await;
            }

            let id = self.next_id.fetch_add(1, Ordering::SeqCst);
            let prev = self.active_processes.fetch_add(1, Ordering::SeqCst);
            let current = prev + 1;
            let mut max = self.max_concurrent.load(Ordering::SeqCst);
            while current > max {
                match self.max_concurrent.compare_exchange_weak(
                    max,
                    current,
                    Ordering::SeqCst,
                    Ordering::SeqCst,
                ) {
                    Ok(_) => break,
                    Err(actual) => max = actual,
                }
            }

            self.history.lock().push(TrackingEvent::Start {
                id,
                transport: rung.transport,
            });

            Ok(CandidateHandle {
                id,
                socks_port: 25000 + (id as u16),
                http_port: Some(26000 + (id as u16)),
                endpoint: endpoint.map(|s| s.to_string()),
            })
        })
    }

    fn verify_path<'a>(
        &'a self,
        handle: &'a CandidateHandle,
    ) -> std::pin::Pin<
        Box<dyn std::future::Future<Output = Result<PathTrace, BackendError>> + Send + 'a>,
    > {
        Box::pin(async move {
            self.history
                .lock()
                .push(TrackingEvent::Verify { id: handle.id });
            if self.fail_verify.load(Ordering::SeqCst) {
                return Err(BackendError::VerificationFailed("Simulated failure".into()));
            }
            Ok(PathTrace {
                ip: "1.1.1.1".into(),
                loc: "US".into(),
                colo: "SFO".into(),
                warp_on: true,
            })
        })
    }

    fn apply_system_tunnel<'a>(
        &'a self,
        handle: &'a CandidateHandle,
        journal: &'a Journal,
    ) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<(), BackendError>> + Send + 'a>>
    {
        Box::pin(async move {
            let _ = journal.record_action(
                "tun",
                serde_json::json!({"id": handle.id}),
                serde_json::json!({"undo": handle.id}),
            );
            self.history
                .lock()
                .push(TrackingEvent::ApplyTunnel { id: handle.id });
            Ok(())
        })
    }

    fn teardown_system_tunnel<'a>(
        &'a self,
        journal: &'a Journal,
    ) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<(), BackendError>> + Send + 'a>>
    {
        Box::pin(async move {
            let _ = journal.clear();
            self.history.lock().push(TrackingEvent::TeardownTunnel);
            Ok(())
        })
    }

    fn stop_candidate<'a>(
        &'a self,
        handle: CandidateHandle,
    ) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<(), BackendError>> + Send + 'a>>
    {
        Box::pin(async move {
            self.active_processes.fetch_sub(1, Ordering::SeqCst);
            self.history
                .lock()
                .push(TrackingEvent::Stop { id: handle.id });
            Ok(())
        })
    }
}

// =============================================================================
// TEST 1: Mode Switching Child Termination Invariant
// =============================================================================
#[tokio::test]
async fn test_mode_switch_terminates_previous_child_before_launching_new() {
    let dir = tempdir().unwrap();
    let journal = Arc::new(Journal::new(dir.path()).unwrap());
    let cache = Arc::new(CacheManager::new(dir.path(), "mode_switch_salt").unwrap());
    let log_ring = LogRingBuffer::new();
    let settings = Arc::new(parking_lot::RwLock::new(Settings {
        connection_mode: ConnectionMode::Masque3,
        ..Default::default()
    }));
    let backend = Arc::new(TrackingBackend::new(Duration::from_millis(5)));

    let (mut sup, state_rx, desired_tx) = Supervisor::new(
        DesiredState {
            intent: DesiredIntent::Down,
            epoch: 0,
        },
        backend.clone(),
        journal.clone(),
        cache.clone(),
        log_ring.clone(),
        settings.clone(),
    );

    let sup_task = tokio::spawn(async move {
        sup.run_reconcile_loop().await;
    });

    // 1. Bring up in Masque3 mode
    desired_tx
        .send(DesiredState {
            intent: DesiredIntent::Up,
            epoch: 1,
        })
        .unwrap();

    // Wait until Connected
    let mut connected = false;
    for _ in 0..50 {
        sleep(Duration::from_millis(20)).await;
        if state_rx.borrow().phase == Phase::Connected {
            connected = true;
            break;
        }
    }
    assert!(connected, "Failed to connect in initial Masque3 mode");
    assert_eq!(backend.active_processes.load(Ordering::SeqCst), 1);

    // Capture the first candidate ID
    let first_cand_id = match backend.history.lock().first().unwrap() {
        TrackingEvent::Start { id, transport } => {
            assert_eq!(*transport, Transport::Masque3);
            *id
        }
        _ => panic!("Expected first event to be Start"),
    };

    // 2. Switch mode to Custom VLESS while connected
    let custom_node = CustomNodeConfig {
        protocol: "vless".to_string(),
        server: "198.51.100.2".to_string(),
        port: 443,
        uuid: "c3bb189e-8bf9-3888-9912-ace4e6543004".to_string(),
        security: Some("reality".to_string()),
        sni: Some("cdn.example.com".to_string()),
        transport: Some("tcp".to_string()),
        path: None,
        fingerprint: Some("chrome".to_string()),
        public_key: Some("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=".to_string()),
        short_id: Some("01234567".to_string()),
        flow: Some("xtls-rprx-vision".to_string()),
    };

    settings.write().connection_mode = ConnectionMode::Custom(Box::new(custom_node));
    // Trigger reconciliation (simulating SetDesired with new epoch)
    desired_tx
        .send(DesiredState {
            intent: DesiredIntent::Up,
            epoch: 2,
        })
        .unwrap();

    // Wait for reconnection in new mode
    let mut reconnected = false;
    for _ in 0..60 {
        sleep(Duration::from_millis(20)).await;
        let st = state_rx.borrow().clone();
        if st.phase == Phase::Connected && st.transport == Transport::Vless {
            reconnected = true;
            break;
        }
    }
    assert!(
        reconnected,
        "Failed to reconnect after mode switch to VLESS. Current state: {:?}",
        state_rx.borrow().phase
    );

    // Check history: Stop of first candidate MUST precede Start of second candidate!
    let history = backend.history.lock().clone();
    let stop_first_idx = history
        .iter()
        .position(|e| matches!(e, TrackingEvent::Stop { id } if *id == first_cand_id))
        .expect("First candidate was never stopped!");

    let start_second_idx = history
        .iter()
        .position(|e| matches!(e, TrackingEvent::Start { id, transport } if *id != first_cand_id && *transport == Transport::Vless))
        .expect("Second candidate was never started!");

    assert!(
        stop_first_idx < start_second_idx,
        "CRITICAL INVARIANT VIOLATION: Previous child (id={}) was stopped at event index {}, but second child was started at event index {}! Old child was NOT terminated before launching new candidate!",
        first_cand_id,
        stop_first_idx,
        start_second_idx
    );

    // Active processes must be exactly 1 now
    assert_eq!(
        backend.active_processes.load(Ordering::SeqCst),
        1,
        "Expected exactly 1 active process after switch"
    );

    // 3. Switch back to WireGuard
    settings.write().connection_mode = ConnectionMode::WireGuard;
    desired_tx
        .send(DesiredState {
            intent: DesiredIntent::Up,
            epoch: 3,
        })
        .unwrap();

    let mut reconnected_wg = false;
    for _ in 0..60 {
        sleep(Duration::from_millis(20)).await;
        let st = state_rx.borrow().clone();
        if st.phase == Phase::Connected && st.transport == Transport::WireGuard {
            reconnected_wg = true;
            break;
        }
    }
    assert!(
        reconnected_wg,
        "Failed to reconnect after mode switch to WireGuard"
    );

    // Teardown cleanly
    desired_tx
        .send(DesiredState {
            intent: DesiredIntent::Down,
            epoch: 4,
        })
        .unwrap();

    let mut idle = false;
    for _ in 0..30 {
        sleep(Duration::from_millis(20)).await;
        if state_rx.borrow().phase == Phase::Idle {
            idle = true;
            break;
        }
    }
    assert!(idle, "Failed to reach Idle on shutdown");
    assert_eq!(
        backend.active_processes.load(Ordering::SeqCst),
        0,
        "Leaked process after teardown"
    );

    sup_task.abort();
}

// =============================================================================
// TEST 2: Settle Window Dampening & Rapid Toggle Flap Prevention
// =============================================================================
#[tokio::test]
async fn test_settle_window_prevents_rapid_toggle_race_conditions() {
    let dir = tempdir().unwrap();
    let journal = Arc::new(Journal::new(dir.path()).unwrap());
    let cache = Arc::new(CacheManager::new(dir.path(), "settle_salt").unwrap());
    let log_ring = LogRingBuffer::new();
    let settings = Arc::new(parking_lot::RwLock::new(Settings::default()));
    let backend = Arc::new(TrackingBackend::new(Duration::from_millis(10)));

    let (mut sup, state_rx, desired_tx) = Supervisor::new(
        DesiredState::default(),
        backend.clone(),
        journal.clone(),
        cache.clone(),
        log_ring.clone(),
        settings.clone(),
    );

    let sup_task = tokio::spawn(async move {
        sup.run_reconcile_loop().await;
    });

    // Rapid toggle flap under 120ms: Up -> wait 40ms -> Down -> wait 40ms -> Up -> wait 40ms -> Down
    for i in 1..=5 {
        let _ = desired_tx.send(DesiredState {
            intent: DesiredIntent::Up,
            epoch: i * 2,
        });
        sleep(Duration::from_millis(35)).await;

        let _ = desired_tx.send(DesiredState {
            intent: DesiredIntent::Down,
            epoch: i * 2 + 1,
        });
        sleep(Duration::from_millis(35)).await;
    }

    // After 5 rapid toggles (each held for 35ms, less than SETTLE_WINDOW_MS = 120ms):
    // The supervisor must NEVER have initiated candidate startup!
    assert_eq!(
        backend.history.lock().len(),
        0,
        "Candidate was started during high-frequency toggle flap! Settle window failed to dampen."
    );
    assert_eq!(state_rx.borrow().phase, Phase::Idle);

    // Now send stable Up intent and wait >= 140ms
    desired_tx
        .send(DesiredState {
            intent: DesiredIntent::Up,
            epoch: 100,
        })
        .unwrap();

    let mut connected = false;
    for _ in 0..30 {
        sleep(Duration::from_millis(20)).await;
        if state_rx.borrow().phase == Phase::Connected {
            connected = true;
            break;
        }
    }
    assert!(
        connected,
        "Failed to connect after intent settled for > 120ms"
    );
    assert_eq!(backend.active_processes.load(Ordering::SeqCst), 1);

    // Teardown
    desired_tx
        .send(DesiredState {
            intent: DesiredIntent::Down,
            epoch: 101,
        })
        .unwrap();
    sleep(Duration::from_millis(50)).await;
    assert_eq!(state_rx.borrow().phase, Phase::Idle);

    sup_task.abort();
}

// =============================================================================
// TEST 3: Zero Zombie Processes & Socket Cleanup Verification
// =============================================================================
#[tokio::test]
async fn test_zero_zombies_and_socket_leak_prevention() {
    use nix::sys::signal::{kill, Signal};
    use nix::unistd::Pid;
    use std::fs;
    use tokio::net::TcpListener;
    use tokio::process::Command;

    // Spawn an actual external child process that:
    // 1. Binds ephemeral port 0 (simulating proxy backend)
    // 2. Ignores SIGTERM initially to stress-test SIGKILL escalation!
    let mut cmd = Command::new("python3");
    cmd.arg("-c").arg(
        r#"
import socket, signal, time, sys

# Set up port listener on port 0 to let OS assign a guaranteed-free port
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.bind(('127.0.0.1', 0))
port = s.getsockname()[1]
s.listen(1)
sys.stdout.write(f"READY {port}\n")
sys.stdout.flush()

# Adversarially ignore SIGTERM!
signal.signal(signal.SIGTERM, signal.SIG_IGN)

while True:
    time.sleep(1)
"#,
    );
    cmd.stdout(std::process::Stdio::piped());
    cmd.stderr(std::process::Stdio::piped());

    let mut child = cmd.spawn().expect("Failed to spawn python child");
    let pid = child.id().expect("Child must have PID");

    // Wait until child signals READY with assigned port
    use tokio::io::AsyncBufReadExt;
    let stdout = child.stdout.take().unwrap();
    let mut reader = tokio::io::BufReader::new(stdout).lines();
    let line = reader.next_line().await.unwrap().unwrap();
    assert!(line.starts_with("READY "), "Unexpected line: {line}");
    let port: u16 = line.strip_prefix("READY ").unwrap().trim().parse().unwrap();

    // Verify child is alive and running via kill(pid, 0)
    assert!(
        kill(Pid::from_raw(pid as i32), None).is_ok(),
        "Child process should be running"
    );

    // Emulate the teardown sequence used by RealAetherBackend and CustomProxyBackend:
    // 1. Send SIGTERM
    let _ = kill(Pid::from_raw(pid as i32), Signal::SIGTERM);

    // 2. Poll up to 300ms for exit
    let mut exit_status = None;
    for _ in 0..6 {
        if let Ok(Some(st)) = child.try_wait() {
            exit_status = Some(st);
            break;
        }
        sleep(Duration::from_millis(50)).await;
    }

    if let Some(ref st) = exit_status {
        eprintln!("Child exited early with status: {:?}", st);
    }

    // Because child ignored SIGTERM, it should NOT have exited via SIGTERM
    assert!(
        exit_status.is_none(),
        "Adversarial child unexpectedly exited on SIGTERM: {:?}",
        exit_status
    );

    // 3. Escalate to SIGKILL!
    let kill_res = child.kill().await;
    assert!(kill_res.is_ok(), "Failed to send SIGKILL to stubborn child");

    // 4. Reap child with wait().await to prevent zombie state
    let wait_res = child.wait().await;
    assert!(wait_res.is_ok(), "Failed to wait on killed child");

    // 5. EMPIRICALLY verify zero zombie in Linux /proc table:
    // If the process was reaped, /proc/{pid}/status is either absent (preferred)
    // or if present (rare caching), its State must NOT be 'Z (zombie)'!
    let proc_status_path = format!("/proc/{pid}/status");
    if let Ok(content) = fs::read_to_string(&proc_status_path) {
        for l in content.lines() {
            if l.starts_with("State:") {
                assert!(
                    !l.contains("Z (zombie)"),
                    "ZOMBIE PROCESS DETECTED in /proc/{pid}/status: {l}"
                );
            }
        }
    }

    // 6. EMPIRICALLY verify socket port is completely released:
    // We must be able to bind to the port immediately without EADDRINUSE!
    let rebind = TcpListener::bind(format!("127.0.0.1:{port}")).await;
    assert!(
        rebind.is_ok(),
        "PORT LEAK DETECTED: Unable to rebind to port {port} immediately after teardown: {:?}",
        rebind.err()
    );
}

// =============================================================================
// TEST 4: Stress 20 Mode Switches Guarantees Zero Overlapping Children
// =============================================================================
#[tokio::test]
async fn test_stress_20_mode_switches_guarantees_max_one_concurrent_child() {
    let dir = tempdir().unwrap();
    let journal = Arc::new(Journal::new(dir.path()).unwrap());
    let cache = Arc::new(CacheManager::new(dir.path(), "stress_salt").unwrap());
    let log_ring = LogRingBuffer::new();
    let settings = Arc::new(parking_lot::RwLock::new(Settings {
        connection_mode: ConnectionMode::Masque3,
        ..Default::default()
    }));
    let backend = Arc::new(TrackingBackend::new(Duration::from_millis(2)));

    let (mut sup, state_rx, desired_tx) = Supervisor::new(
        DesiredState {
            intent: DesiredIntent::Down,
            epoch: 0,
        },
        backend.clone(),
        journal.clone(),
        cache.clone(),
        log_ring.clone(),
        settings.clone(),
    );

    let sup_task = tokio::spawn(async move {
        sup.run_reconcile_loop().await;
    });

    let vless_node = CustomNodeConfig {
        protocol: "vless".to_string(),
        server: "1.1.1.1".to_string(),
        port: 443,
        uuid: "c3bb189e-8bf9-3888-9912-ace4e6543004".to_string(),
        security: Some("reality".to_string()),
        sni: Some("cdn.example.com".to_string()),
        transport: Some("tcp".to_string()),
        path: None,
        fingerprint: Some("chrome".to_string()),
        public_key: Some("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=".to_string()),
        short_id: Some("01234567".to_string()),
        flow: Some("xtls-rprx-vision".to_string()),
    };

    let vmess_node = CustomNodeConfig {
        protocol: "vmess".to_string(),
        server: "2.2.2.2".to_string(),
        port: 8443,
        uuid: "d3bb189e-8bf9-3888-9912-ace4e6543005".to_string(),
        security: Some("tls".to_string()),
        sni: Some("vmess.example.com".to_string()),
        transport: Some("ws".to_string()),
        path: Some("/ws".to_string()),
        fingerprint: None,
        public_key: None,
        short_id: None,
        flow: None,
    };

    let modes = [
        ConnectionMode::Masque3,
        ConnectionMode::Custom(Box::new(vless_node)),
        ConnectionMode::WireGuard,
        ConnectionMode::Custom(Box::new(vmess_node)),
        ConnectionMode::Masque2,
    ];

    // Initial connect
    desired_tx
        .send(DesiredState {
            intent: DesiredIntent::Up,
            epoch: 1,
        })
        .unwrap();

    let mut connected = false;
    for _ in 0..40 {
        sleep(Duration::from_millis(20)).await;
        if state_rx.borrow().phase == Phase::Connected {
            connected = true;
            break;
        }
    }
    assert!(connected, "Initial connection failed");

    // Perform 20 mode switches
    for epoch in 2..=21 {
        let target_mode = modes[(epoch as usize) % modes.len()].clone();
        settings.write().connection_mode = target_mode;
        desired_tx
            .send(DesiredState {
                intent: DesiredIntent::Up,
                epoch,
            })
            .unwrap();

        // Wait until it reaches Connected in the new epoch
        let mut switched = false;
        for _ in 0..50 {
            sleep(Duration::from_millis(20)).await;
            if state_rx.borrow().phase == Phase::Connected {
                switched = true;
                break;
            }
        }
        assert!(switched, "Failed to switch mode at epoch {epoch}");

        // Invariant: Concurrent active processes must NEVER exceed 1 during mode switches
        let cur_procs = backend.active_processes.load(Ordering::SeqCst);
        assert_eq!(
            cur_procs, 1,
            "Epoch {epoch}: expected exactly 1 active process while connected, found {cur_procs}"
        );
    }

    assert_eq!(
        backend.max_concurrent.load(Ordering::SeqCst),
        1,
        "Max concurrent processes exceeded 1 during 20 mode switches! Candidates overlapped."
    );

    // Final clean teardown
    desired_tx
        .send(DesiredState {
            intent: DesiredIntent::Down,
            epoch: 22,
        })
        .unwrap();

    let mut idle = false;
    for _ in 0..30 {
        sleep(Duration::from_millis(20)).await;
        if state_rx.borrow().phase == Phase::Idle {
            idle = true;
            break;
        }
    }
    assert!(idle, "Failed to reach Idle on shutdown");
    assert_eq!(
        backend.active_processes.load(Ordering::SeqCst),
        0,
        "Leaked process after teardown"
    );

    sup_task.abort();
}

// =============================================================================
// TEST 5: Mode Switch / Down Interrupt During In-Flight Bring-Up
// =============================================================================
#[tokio::test]
async fn test_mode_switch_interruption_during_bring_up() {
    let dir = tempdir().unwrap();
    let journal = Arc::new(Journal::new(dir.path()).unwrap());
    let cache = Arc::new(CacheManager::new(dir.path(), "interrupt_salt").unwrap());
    let log_ring = LogRingBuffer::new();
    let settings = Arc::new(parking_lot::RwLock::new(Settings {
        connection_mode: ConnectionMode::Masque3,
        ..Default::default()
    }));
    // High start delay to guarantee we can interrupt during bring_up
    let backend = Arc::new(TrackingBackend::new(Duration::from_millis(150)));

    let (mut sup, state_rx, desired_tx) = Supervisor::new(
        DesiredState {
            intent: DesiredIntent::Down,
            epoch: 0,
        },
        backend.clone(),
        journal.clone(),
        cache.clone(),
        log_ring.clone(),
        settings.clone(),
    );

    let sup_task = tokio::spawn(async move {
        sup.run_reconcile_loop().await;
    });

    // Start bring-up
    desired_tx
        .send(DesiredState {
            intent: DesiredIntent::Up,
            epoch: 1,
        })
        .unwrap();

    // Wait until it enters Connecting
    let mut connecting = false;
    for _ in 0..30 {
        sleep(Duration::from_millis(15)).await;
        if state_rx.borrow().phase == Phase::Connecting {
            connecting = true;
            break;
        }
    }
    assert!(connecting, "Failed to enter Connecting phase");

    // While in-flight, interrupt with Down!
    desired_tx
        .send(DesiredState {
            intent: DesiredIntent::Down,
            epoch: 2,
        })
        .unwrap();

    // Supervisor must interrupt bring_up, call tear_down, and reach Idle
    let mut idle = false;
    for _ in 0..40 {
        sleep(Duration::from_millis(20)).await;
        if state_rx.borrow().phase == Phase::Idle {
            idle = true;
            break;
        }
    }
    assert!(
        idle,
        "Failed to reach Idle after in-flight interruption. State: {:?}",
        state_rx.borrow().phase
    );

    // Verify zero leaked processes
    assert_eq!(
        backend.active_processes.load(Ordering::SeqCst),
        0,
        "Leaked process after in-flight bring-up interruption"
    );

    sup_task.abort();
}
