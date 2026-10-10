use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::signal;
use tracing::{error, info, warn};
use zohal_engine::backend::TunnelBackend;
use zohal_engine::cache::CacheManager;
use zohal_engine::ipc::IpcServer;
use zohal_engine::ipc_client::IpcClient;
use zohal_engine::journal::Journal;
use zohal_engine::ladder::RungConfig;
use zohal_engine::log_ring::LogRingBuffer;
use zohal_engine::real_backend::RealAetherBackend;
use zohal_engine::supervisor::Supervisor;
use zohal_platform::linux::LinuxPlatform;
use zohal_proto::settings::Settings;
use zohal_proto::types::{DesiredIntent, DesiredState, NoizeProfile, ScanProfile, Transport};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt::init();

    let args: Vec<String> = std::env::args().collect();
    let cmd = args.get(1).map(|s| s.as_str()).unwrap_or("service");

    match cmd {
        "service" => run_service().await?,
        "user" => run_user_proxy().await?,
        "cleanup" => run_cleanup()?,
        "status" => run_status().await?,
        "install" => run_install()?,
        "uninstall" => run_uninstall()?,
        "bench" => run_bench(&args[2..]).await?,
        _ => {
            eprintln!("Usage: zohald [service|user|cleanup|status|install|uninstall|bench]");
            std::process::exit(1);
        }
    }

    Ok(())
}

fn get_user_runtime_dir() -> PathBuf {
    let dir = if let Ok(xdg) = std::env::var("XDG_RUNTIME_DIR") {
        PathBuf::from(xdg).join("zohal")
    } else if let Ok(home) = std::env::var("HOME") {
        PathBuf::from(home).join(".local/share/zohal")
    } else {
        std::env::temp_dir().join("zohal_user")
    };

    #[cfg(unix)]
    {
        use std::os::unix::fs::DirBuilderExt;
        let mut builder = std::fs::DirBuilder::new();
        builder.recursive(true);
        builder.mode(0o700);
        let _ = builder.create(&dir);
    }
    #[cfg(not(unix))]
    {
        let _ = std::fs::create_dir_all(&dir);
    }
    dir
}

fn find_aether_bin() -> PathBuf {
    let mut candidates = Vec::new();
    if let Ok(exe) = std::env::current_exe() {
        if let Some(parent) = exe.parent() {
            candidates.push(parent.join("aether"));
            candidates.push(parent.join("usr/bin/aether"));
        }
    }
    if let Ok(appdir) = std::env::var("ZOHAL_APPDIR") {
        candidates.push(PathBuf::from(appdir).join("usr/bin/aether"));
    }
    candidates.push(PathBuf::from("/usr/lib/zohal/aether"));
    candidates.push(PathBuf::from("/usr/bin/aether"));
    candidates.push(PathBuf::from("/opt/zohal/aether"));
    candidates.push(PathBuf::from("third_party/dist/linux-x86_64/aether"));

    for c in &candidates {
        if c.exists() {
            info!("[zohald] found aether binary at {:?}", c);
            return c.clone();
        }
    }
    warn!("[zohald] aether binary not found in candidate paths, falling back to 'aether'");
    PathBuf::from("aether")
}

async fn run_service() -> Result<(), Box<dyn std::error::Error>> {
    info!("[zohald] starting Zohal Connect service");

    let runtime_dir = std::env::var("RUNTIME_DIRECTORY")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("/run/zohal"));
    let state_dir = std::env::var("STATE_DIRECTORY")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("/var/lib/zohal"));

    // Ensure directories exist or fallback to tmp
    let (data_dir, sock_path) = if std::fs::create_dir_all(&state_dir).is_ok()
        && std::fs::create_dir_all(&runtime_dir).is_ok()
    {
        (state_dir, runtime_dir.join("engine.sock"))
    } else {
        let tmp = std::env::temp_dir().join("zohal");
        let _ = std::fs::create_dir_all(&tmp);
        (tmp.clone(), tmp.join("engine.sock"))
    };

    info!(
        "[zohald] using data_dir: {:?}, sock: {:?}",
        data_dir, sock_path
    );

    // 1. Crash recovery: journal undo
    let journal = Arc::new(Journal::new(&data_dir)?);
    let platform = LinuxPlatform::default();
    struct DummyUndo<'a>(&'a LinuxPlatform);
    impl<'a> zohal_engine::journal::UndoHandler for DummyUndo<'a> {
        fn execute_undo(
            &self,
            action: &zohal_engine::journal::JournalAction,
        ) -> Result<(), String> {
            info!(
                "[journal/recovery] executing undo for action kind: {}",
                action.kind
            );
            if action.kind == "system_proxy" {
                let prev = action.undo.get("prev").cloned();
                let proxy = zohal_platform::proxy_only::DesktopSystemProxy::default();
                let _ = proxy.disable_system_proxy(prev.as_ref());
            }
            let _ = self.0.teardown_all();
            Ok(())
        }
    }
    let undone = journal.run_recovery(&DummyUndo(&platform))?;
    if undone > 0 {
        info!(
            "[zohald] crash recovery undone {} uncommitted actions",
            undone
        );
    }

    // 2. Locate Aether binary
    let aether_bin = find_aether_bin();
    info!("[zohald] using aether binary: {:?}", aether_bin);

    let cache = Arc::new(CacheManager::new(&data_dir, "zohal_salt_host")?);
    let log_ring = LogRingBuffer::new();
    let settings = Arc::new(parking_lot::RwLock::new(Settings::default()));

    let backend = Arc::new(RealAetherBackend::new(aether_bin, &data_dir));

    let initial_desired = DesiredState {
        intent: DesiredIntent::Down,
        epoch: 0,
    };

    let (mut supervisor, state_rx, desired_tx) = Supervisor::new(
        initial_desired,
        backend,
        journal,
        cache,
        log_ring.clone(),
        settings.clone(),
    );

    // 3. Start supervisor loop
    let sup_handle = tokio::spawn(async move {
        supervisor.run_reconcile_loop().await;
    });

    // 4. Start IPC server
    let server = IpcServer::new(
        sock_path.clone(),
        state_rx,
        desired_tx.clone(),
        settings,
        log_ring,
    );

    let srv_handle = tokio::spawn(async move {
        if let Err(e) = server.run().await {
            error!("[zohald] IPC server terminated: {e}");
        }
    });

    // 5. Notify systemd ready
    let _ = sd_notify::notify(&[sd_notify::NotifyState::Ready]);
    info!("[zohald] service ready and listening");

    // Wait for shutdown signal
    match signal::ctrl_c().await {
        Ok(()) => info!("[zohald] shutdown signal received"),
        Err(err) => error!("[zohald] failed to listen for shutdown: {err}"),
    }

    // Graceful teardown
    let _ = desired_tx.send(DesiredState {
        intent: DesiredIntent::Down,
        epoch: 999_999,
    });
    tokio::time::sleep(std::time::Duration::from_millis(400)).await;

    let _ = sd_notify::notify(&[sd_notify::NotifyState::Stopping]);
    sup_handle.abort();
    srv_handle.abort();
    let _ = std::fs::remove_file(sock_path);

    info!("[zohald] service stopped cleanly");
    Ok(())
}

async fn run_user_proxy() -> Result<(), Box<dyn std::error::Error>> {
    info!("[zohald] starting user proxy mode");
    // User-level system proxy mode
    let user_dir = get_user_runtime_dir();
    let sock_path = user_dir.join("user_engine.sock");

    let cache = Arc::new(CacheManager::new(&user_dir, "zohal_user_salt")?);
    let log_ring = LogRingBuffer::new();
    let settings = Arc::new(parking_lot::RwLock::new(Settings {
        scope: zohal_proto::types::Scope::SystemProxy,
        ..Default::default()
    }));
    let journal = Arc::new(Journal::new(&user_dir)?);

    let aether_bin = find_aether_bin();
    let backend = Arc::new(RealAetherBackend::new(aether_bin, &user_dir));

    let (mut supervisor, state_rx, desired_tx) = Supervisor::new(
        DesiredState::default(),
        backend,
        journal,
        cache,
        log_ring.clone(),
        settings.clone(),
    );

    tokio::spawn(async move {
        supervisor.run_reconcile_loop().await;
    });

    let server = IpcServer::new(sock_path.clone(), state_rx, desired_tx, settings, log_ring);
    tokio::spawn(async move {
        let _ = server.run().await;
    });

    info!("[zohald] user proxy listening on {:?}", sock_path);
    signal::ctrl_c().await?;
    let _ = std::fs::remove_file(sock_path);
    Ok(())
}

fn run_cleanup() -> Result<(), Box<dyn std::error::Error>> {
    info!("[zohald] emergency cleanup requested");
    let platform = LinuxPlatform::default();
    let _ = platform.teardown_all();
    let tmp = std::env::temp_dir().join("zohal");
    if tmp.exists() {
        let _ = std::fs::remove_dir_all(tmp);
    }
    info!("[zohald] cleanup completed");
    Ok(())
}

async fn run_status() -> Result<(), Box<dyn std::error::Error>> {
    let sock_path = Path::new("/run/zohal/engine.sock");
    let fallback = std::env::temp_dir().join("zohal").join("engine.sock");

    let target = if sock_path.exists() {
        sock_path
    } else {
        fallback.as_path()
    };

    match IpcClient::connect(target).await {
        Ok(mut client) => {
            let state = client.get_state().await.map_err(|e| format!("{e}"))?;
            println!("{}", serde_json::to_string_pretty(&state)?);
        }
        Err(e) => {
            eprintln!("Cannot connect to Zohal service: {e}");
            std::process::exit(1);
        }
    }
    Ok(())
}

fn run_install() -> Result<(), Box<dyn std::error::Error>> {
    println!("Zohal service installed.");
    Ok(())
}

fn run_uninstall() -> Result<(), Box<dyn std::error::Error>> {
    run_cleanup()
}

async fn run_bench(args: &[String]) -> Result<(), Box<dyn std::error::Error>> {
    let mut runs = 20;
    let mut i = 0;
    while i < args.len() {
        if args[i] == "--runs" && i + 1 < args.len() {
            if let Ok(n) = args[i + 1].parse::<usize>() {
                runs = n;
            }
            i += 2;
        } else {
            i += 1;
        }
    }
    run_bench_connect(runs).await
}

async fn run_bench_connect(runs: usize) -> Result<(), Box<dyn std::error::Error>> {
    println!("=== Zohal Connect Benchmark (runs: {}) ===", runs);
    let tmp = std::env::temp_dir().join(format!("zohal_bench_{}", std::process::id()));
    std::fs::create_dir_all(&tmp)?;

    let aether_bin = find_aether_bin();
    println!("Using aether binary: {:?}", aether_bin);
    let backend = Arc::new(RealAetherBackend::new(aether_bin, &tmp));

    let mut gateway_times = Vec::with_capacity(runs);
    let mut build_times = Vec::with_capacity(runs);
    let mut verify_times = Vec::with_capacity(runs);
    let mut total_times = Vec::with_capacity(runs);

    let rung = RungConfig {
        rung_number: 1,
        transport: Transport::Masque2,
        scan: ScanProfile::Turbo,
        noize: NoizeProfile::Firewall,
        use_cache: true,
        h2_proven_only: true,
        fragment: true,
        deadline: Duration::from_secs(5),
    };

    for run_idx in 1..=runs {
        print!("Run {:2}/{:2}: ", run_idx, runs);
        let _ = std::io::stdout().flush();

        let t0 = Instant::now();
        let cand = match backend.start_candidate(&rung, None).await {
            Ok(c) => c,
            Err(e) => {
                println!("start_candidate failed: {:?}", e);
                continue;
            }
        };
        let t_gw = t0.elapsed();

        let t1 = Instant::now();
        let journal = Journal::new(&tmp)?;
        if let Err(e) = backend.apply_system_tunnel(&cand, &journal).await {
            println!("apply_system_tunnel failed: {:?}", e);
            let _ = backend.stop_candidate(cand).await;
            continue;
        }
        let t_build = t1.elapsed();

        let t2 = Instant::now();
        if let Err(e) = backend.verify_path(&cand).await {
            println!("verify_path failed: {:?}", e);
            let _ = backend.teardown_system_tunnel(&journal).await;
            let _ = backend.stop_candidate(cand).await;
            continue;
        }
        let t_ver = t2.elapsed();
        let t_tot = t0.elapsed();

        let _ = backend.teardown_system_tunnel(&journal).await;
        let _ = backend.stop_candidate(cand).await;

        gateway_times.push(t_gw.as_millis() as f64);
        build_times.push(t_build.as_millis() as f64);
        verify_times.push(t_ver.as_millis() as f64);
        total_times.push(t_tot.as_millis() as f64);

        println!(
            "gw: {:4.0}ms, build: {:3.0}ms, verify: {:3.0}ms, total: {:4.0}ms",
            t_gw.as_millis(),
            t_build.as_millis(),
            t_ver.as_millis(),
            t_tot.as_millis()
        );
    }

    let _ = std::fs::remove_dir_all(&tmp);

    fn calc_stats(mut v: Vec<f64>) -> (f64, f64, f64, f64, f64) {
        if v.is_empty() {
            return (0.0, 0.0, 0.0, 0.0, 0.0);
        }
        v.sort_by(|a, b| a.partial_cmp(b).unwrap());
        let min = v[0];
        let max = *v.last().unwrap();
        let mean = v.iter().sum::<f64>() / v.len() as f64;
        let p50 = v[v.len() / 2];
        let p95_idx = ((v.len() as f64 * 0.95) as usize).min(v.len() - 1);
        let p95 = v[p95_idx];
        (min, mean, p50, p95, max)
    }

    println!("\n=== Benchmark Summary (N={}) ===", gateway_times.len());
    println!(
        "{:<16} | {:>8} | {:>8} | {:>8} | {:>8} | {:>8}",
        "Stage", "Min(ms)", "Mean(ms)", "P50(ms)", "P95(ms)", "Max(ms)"
    );
    println!(
        "{:-<16}-|-{:-<8}-|-{:-<8}-|-{:-<8}-|-{:-<8}-|-{:-<8}",
        "", "", "", "", "", ""
    );
    let (g_min, g_mean, g_p50, g_p95, g_max) = calc_stats(gateway_times);
    println!(
        "{:<16} | {:8.1} | {:8.1} | {:8.1} | {:8.1} | {:8.1}",
        "Find Gateway", g_min, g_mean, g_p50, g_p95, g_max
    );
    let (b_min, b_mean, b_p50, b_p95, b_max) = calc_stats(build_times);
    println!(
        "{:<16} | {:8.1} | {:8.1} | {:8.1} | {:8.1} | {:8.1}",
        "Build Tunnel", b_min, b_mean, b_p50, b_p95, b_max
    );
    let (v_min, v_mean, v_p50, v_p95, v_max) = calc_stats(verify_times);
    println!(
        "{:<16} | {:8.1} | {:8.1} | {:8.1} | {:8.1} | {:8.1}",
        "Verify Path", v_min, v_mean, v_p50, v_p95, v_max
    );
    let (t_min, t_mean, t_p50, t_p95, t_max) = calc_stats(total_times);
    println!(
        "{:<16} | {:8.1} | {:8.1} | {:8.1} | {:8.1} | {:8.1}",
        "Total Connect", t_min, t_mean, t_p50, t_p95, t_max
    );

    Ok(())
}
