use crate::backend::{BackendError, CandidateHandle, PathTrace, TunnelBackend};
use crate::journal::Journal;
use crate::ladder::RungConfig;
use nix::sys::signal::{kill, Signal};
use nix::unistd::Pid;
use std::collections::HashMap;
use std::future::Future;
use std::path::PathBuf;
use std::pin::Pin;
use std::process::Stdio;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Duration;
use tokio::io::AsyncReadExt;
use tokio::net::TcpStream;
use tokio::process::Command;
use tokio::time::sleep;
use tracing::{info, warn};
use zohal_platform::linux::{LinuxNetworkConfig, LinuxPlatform, DEFAULT_FWMARK};
use zohal_platform::prober::probe_free_port;
use zohal_proto::types::Transport;
use zohal_tun::{Tun2ProxyFrontend, TunFrontend};

pub struct RealAetherBackend {
    binary_path: PathBuf,
    data_dir: PathBuf,
    platform: Arc<LinuxPlatform>,
    tun_frontend: Arc<parking_lot::Mutex<Tun2ProxyFrontend>>,
    children: Arc<parking_lot::Mutex<HashMap<u64, tokio::process::Child>>>,
    next_id: Arc<AtomicU64>,
}

impl RealAetherBackend {
    pub fn new(binary_path: impl Into<PathBuf>, data_dir: impl Into<PathBuf>) -> Self {
        Self {
            binary_path: binary_path.into(),
            data_dir: data_dir.into(),
            platform: Arc::new(LinuxPlatform::new(LinuxNetworkConfig::default())),
            tun_frontend: Arc::new(parking_lot::Mutex::new(Tun2ProxyFrontend::new())),
            children: Arc::new(parking_lot::Mutex::new(HashMap::new())),
            next_id: Arc::new(AtomicU64::new(1)),
        }
    }
}

impl TunnelBackend for RealAetherBackend {
    fn start_candidate<'a>(
        &'a self,
        rung: &'a RungConfig,
        endpoint: Option<&'a str>,
    ) -> Pin<Box<dyn Future<Output = Result<CandidateHandle, BackendError>> + Send + 'a>> {
        Box::pin(async move {
            let id = self.next_id.fetch_add(1, Ordering::Relaxed);
            let socks_port = probe_free_port(22000, 32000).map_err(BackendError::PortBind)?;
            let http_port = probe_free_port(32001, 42000).map_err(BackendError::PortBind)?;

            let mut cmd = Command::new(&self.binary_path);
            cmd.stdin(Stdio::null());
            cmd.stdout(Stdio::piped());
            cmd.stderr(Stdio::piped());

            // Add verified Aether flags (exact names from docs/AETHER_NOTES.md:
            // --masque/--h3/--h2/--wg/--gool/--gool-classic, --scan, --noize)
            match rung.transport {
                Transport::Masque3 => {
                    cmd.arg("--masque");
                    cmd.arg("--h3");
                }
                Transport::Masque2 => {
                    cmd.arg("--masque");
                    cmd.arg("--h2");
                    if rung.fragment {
                        cmd.arg("--fragment");
                    }
                }
                Transport::WireGuard => {
                    cmd.arg("--wg");
                }
                Transport::GoolMasque => {
                    cmd.arg("--gool");
                }
                Transport::GoolClassic => {
                    cmd.arg("--gool-classic");
                }
                Transport::None => {}
            }

            cmd.arg("--bind").arg(format!("127.0.0.1:{socks_port}"));
            cmd.arg("--http-proxy")
                .arg(format!("127.0.0.1:{http_port}"));

            // Obfuscation and scan modes
            let scan_mode = format!("{:?}", rung.scan).to_lowercase();
            cmd.arg("--scan").arg(&scan_mode);

            let noize_mode = format!("{:?}", rung.noize).to_lowercase();
            cmd.arg("--noize").arg(&noize_mode);

            // Config directory
            cmd.arg("--config").arg(&self.data_dir);

            // Marks for Linux loop prevention
            cmd.arg("--mark").arg(DEFAULT_FWMARK.to_string());

            if let Some(peer) = endpoint {
                cmd.arg("--peer").arg(peer);
            } else if rung.use_cache {
                cmd.arg("--quick-reconnect");
            }

            // Stdin closed & pre_exec PDEATHSIG
            #[cfg(target_os = "linux")]
            unsafe {
                cmd.pre_exec(|| {
                    libc::prctl(libc::PR_SET_PDEATHSIG, libc::SIGTERM);
                    Ok(())
                });
            }

            info!(
                "[aether] spawning candidate id={} on port {} with rung {:?}",
                id, socks_port, rung.rung_number
            );

            let mut child = cmd
                .spawn()
                .map_err(|e| BackendError::ProcessFailed(format!("Failed to spawn Aether: {e}")))?;

            // Capture child logs in background task
            if let Some(mut stdout) = child.stdout.take() {
                tokio::spawn(async move {
                    let mut buf = [0u8; 1024];
                    while let Ok(n) = stdout.read(&mut buf).await {
                        if n == 0 {
                            break;
                        }
                    }
                });
            }

            self.children.lock().insert(id, child);

            // Wait for SOCKS port readiness (Aether opens SOCKS only after data-plane is validated)
            let start_poll = std::time::Instant::now();
            let mut ready = false;
            let check_addr = format!("127.0.0.1:{socks_port}");

            while start_poll.elapsed() < rung.deadline {
                if TcpStream::connect(&check_addr).await.is_ok() {
                    ready = true;
                    break;
                }
                sleep(Duration::from_millis(50)).await;
            }

            if !ready {
                warn!(
                    "[aether] candidate id={} timed out waiting for SOCKS port readiness",
                    id
                );
                let maybe_child = { self.children.lock().remove(&id) };
                if let Some(mut ch) = maybe_child {
                    let _ = ch.kill().await;
                }
                return Err(BackendError::Timeout);
            }

            info!("[aether] candidate id={} ready on {}", id, check_addr);
            Ok(CandidateHandle {
                id,
                socks_port,
                http_port: Some(http_port),
                endpoint: endpoint.map(|s| s.to_string()),
            })
        })
    }

    fn verify_path<'a>(
        &'a self,
        handle: &'a CandidateHandle,
    ) -> Pin<Box<dyn Future<Output = Result<PathTrace, BackendError>> + Send + 'a>> {
        Box::pin(async move {
            let proxy_url = format!("socks5h://127.0.0.1:{}", handle.socks_port);
            let target_url = "https://1.1.1.1/cdn-cgi/trace";

            info!(
                "[verify] probing trace through candidate id={} ({})",
                handle.id, proxy_url
            );

            let proxy_agent = ureq::Proxy::new(&proxy_url)
                .map_err(|e| BackendError::VerificationFailed(e.to_string()))?;
            let agent = ureq::builder()
                .proxy(proxy_agent)
                .timeout(Duration::from_secs(3))
                .build();

            let body = tokio::task::spawn_blocking(move || {
                agent
                    .get(target_url)
                    .call()
                    .map_err(|e| e.to_string())
                    .and_then(|resp| resp.into_string().map_err(|e| e.to_string()))
            })
            .await
            .map_err(|e| BackendError::VerificationFailed(e.to_string()))?
            .map_err(BackendError::VerificationFailed)?;

            if !body.contains("warp=on") && !body.contains("warp=plus") {
                return Err(BackendError::VerificationFailed(
                    "Missing warp=on in trace body".into(),
                ));
            }

            let mut ip = "unknown".to_string();
            let mut loc = "unknown".to_string();
            let mut colo = "unknown".to_string();

            for line in body.lines() {
                if let Some((k, v)) = line.split_once('=') {
                    match k.trim() {
                        "ip" => ip = v.trim().to_string(),
                        "loc" => loc = v.trim().to_string(),
                        "colo" => colo = v.trim().to_string(),
                        _ => {}
                    }
                }
            }

            info!(
                "[verify] path verified: ip={} loc={} colo={}",
                ip, loc, colo
            );
            Ok(PathTrace {
                ip,
                loc,
                colo,
                warp_on: true,
            })
        })
    }

    fn apply_system_tunnel<'a>(
        &'a self,
        handle: &'a CandidateHandle,
        journal: &'a Journal,
    ) -> Pin<Box<dyn Future<Output = Result<(), BackendError>> + Send + 'a>> {
        Box::pin(async move {
            info!(
                "[platform] applying system tunnel on zohal0 for candidate id={}",
                handle.id
            );

            // Unprivileged fallback (AppImage/tarball without the system
            // service): no TUN without root, so apply the per-user system
            // proxy scope instead. Still a real working path: all desktop
            // traffic honoring the system proxy goes through Aether.
            #[cfg(target_os = "linux")]
            if unsafe { libc::geteuid() } != 0 {
                info!("[platform] unprivileged user scope: applying system proxy");
                let proxy = zohal_platform::proxy_only::DesktopSystemProxy::default();
                let prev = proxy
                    .enable_system_proxy(
                        handle.http_port.unwrap_or(handle.socks_port),
                        handle.socks_port,
                    )
                    .map_err(BackendError::SystemConfig)?;
                let undo = serde_json::json!({"action": "proxy_restore", "prev": prev});
                let _ = journal.record_action(
                    "system_proxy",
                    serde_json::json!({"socks": handle.socks_port}),
                    undo,
                );
                return Ok(());
            }

            // 1. Start tun2proxy on zohal0
            self.tun_frontend
                .lock()
                .start("zohal0", handle.socks_port, 1280)
                .map_err(BackendError::SystemConfig)?;

            // 2. Journal and apply TUN device
            let tun_undo = serde_json::json!({"action": "tun_down", "dev": "zohal0"});
            let _ =
                journal.record_action("tun_device", serde_json::json!({"dev": "zohal0"}), tun_undo);
            let _ = self.platform.apply_tun_device();

            // 3. Journal and apply policy routing
            let route_undo = serde_json::json!({"action": "policy_revert", "table": 100});
            let _ = journal.record_action(
                "policy_routing",
                serde_json::json!({"table": 100}),
                route_undo,
            );
            if let Err(e) = self.platform.apply_policy_routing() {
                warn!("[platform] policy routing notice (non-root test fallback): {e}");
            }

            // 4. Journal and apply DNS
            let dns_undo = serde_json::json!({"action": "dns_revert", "dev": "zohal0"});
            let _ = journal.record_action("dns", serde_json::json!({"dev": "zohal0"}), dns_undo);
            let dns_servers = vec![
                "1.1.1.1".to_string(),
                "1.0.0.1".to_string(),
                "2606:4700:4700::1111".to_string(),
                "2606:4700:4700::1001".to_string(),
            ];
            let _ = self.platform.apply_dns(&dns_servers);

            Ok(())
        })
    }

    fn teardown_system_tunnel<'a>(
        &'a self,
        journal: &'a Journal,
    ) -> Pin<Box<dyn Future<Output = Result<(), BackendError>> + Send + 'a>> {
        Box::pin(async move {
            info!("[platform] tearing down system tunnel");
            let _ = self.tun_frontend.lock().stop();
            // Restore an unprivileged user-scope system proxy if one was applied.
            #[cfg(target_os = "linux")]
            if let Ok(actions) = journal.read_actions() {
                for action in actions.iter().rev() {
                    if action.kind == "system_proxy" {
                        let prev = action.undo.get("prev").cloned();
                        let proxy = zohal_platform::proxy_only::DesktopSystemProxy::default();
                        let _ = proxy.disable_system_proxy(prev.as_ref());
                    }
                }
            }
            let _ = self.platform.teardown_all();
            let _ = journal.clear();
            Ok(())
        })
    }

    fn stop_candidate<'a>(
        &'a self,
        handle: CandidateHandle,
    ) -> Pin<Box<dyn Future<Output = Result<(), BackendError>> + Send + 'a>> {
        Box::pin(async move {
            info!("[aether] stopping candidate id={}", handle.id);
            let maybe_child = { self.children.lock().remove(&handle.id) };
            if let Some(mut child) = maybe_child {
                if let Some(pid) = child.id() {
                    // Polite kill with SIGTERM
                    let _ = kill(Pid::from_raw(pid as i32), Signal::SIGTERM);
                    // Wait up to 300 ms for exit
                    let mut exited = false;
                    for _ in 0..6 {
                        if child.try_wait().ok().flatten().is_some() {
                            exited = true;
                            break;
                        }
                        sleep(Duration::from_millis(50)).await;
                    }
                    if !exited {
                        warn!("[aether] escalating to SIGKILL for pid={pid}");
                        let _ = child.kill().await;
                    }
                }
            }
            Ok(())
        })
    }
}
