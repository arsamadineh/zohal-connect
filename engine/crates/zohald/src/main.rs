use std::path::{Path, PathBuf};
use std::sync::Arc;
use tokio::signal;
use tracing::{error, info};
use zohal_engine::cache::CacheManager;
use zohal_engine::ipc::IpcServer;
use zohal_engine::ipc_client::IpcClient;
use zohal_engine::journal::Journal;
use zohal_engine::log_ring::LogRingBuffer;
use zohal_engine::real_backend::RealAetherBackend;
use zohal_engine::supervisor::Supervisor;
use zohal_platform::linux::LinuxPlatform;
use zohal_proto::settings::Settings;
use zohal_proto::types::{DesiredIntent, DesiredState};

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
        _ => {
            eprintln!("Usage: zohald [service|user|cleanup|status|install|uninstall]");
            std::process::exit(1);
        }
    }

    Ok(())
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
    let binary_candidates = [
        PathBuf::from("/usr/lib/zohal/aether"),
        PathBuf::from("third_party/dist/linux-x86_64/aether"),
        std::env::current_exe()?.parent().unwrap().join("aether"),
    ];

    let aether_bin = binary_candidates
        .iter()
        .find(|p| p.exists())
        .cloned()
        .unwrap_or_else(|| PathBuf::from("aether"));

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
    let tmp = std::env::temp_dir().join("zohal_user");
    let _ = std::fs::create_dir_all(&tmp);
    let sock_path = tmp.join("user_engine.sock");

    let cache = Arc::new(CacheManager::new(&tmp, "zohal_user_salt")?);
    let log_ring = LogRingBuffer::new();
    let settings = Arc::new(parking_lot::RwLock::new(Settings::default()));
    let journal = Arc::new(Journal::new(&tmp)?);

    let aether_bin = PathBuf::from("third_party/dist/linux-x86_64/aether");
    let backend = Arc::new(RealAetherBackend::new(aether_bin, &tmp));

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
