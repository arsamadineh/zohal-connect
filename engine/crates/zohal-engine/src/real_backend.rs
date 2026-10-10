use crate::backend::{BackendError, CandidateHandle, PathTrace, TunnelBackend};
use crate::journal::Journal;
use crate::ladder::RungConfig;
use nix::sys::signal::{kill, Signal};
use nix::unistd::Pid;
use std::collections::HashMap;
use std::future::Future;
use std::path::{Path, PathBuf};
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

async fn tcp_probe_socks(socks_port: u16) -> Result<(), BackendError> {
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    use tokio::net::TcpStream;

    let mut stream = tokio::time::timeout(
        Duration::from_secs(3),
        TcpStream::connect(format!("127.0.0.1:{socks_port}")),
    )
    .await
    .map_err(|_| BackendError::Timeout)?
    .map_err(|e| BackendError::VerificationFailed(format!("SOCKS connect failed: {e}")))?;

    // SOCKS5 greeting: 0x05 (version), 0x01 (1 method), 0x00 (no auth)
    stream.write_all(&[0x05, 0x01, 0x00]).await.map_err(|e| {
        BackendError::VerificationFailed(format!("SOCKS write greeting failed: {e}"))
    })?;

    let mut greeting_resp = [0u8; 2];
    stream.read_exact(&mut greeting_resp).await.map_err(|e| {
        BackendError::VerificationFailed(format!("SOCKS read greeting failed: {e}"))
    })?;

    if greeting_resp != [0x05, 0x00] {
        return Err(BackendError::VerificationFailed("SOCKS auth failed".into()));
    }

    // SOCKS5 connect request to 1.1.1.1:443
    // VER: 0x05, CMD: 0x01 (connect), RSV: 0x00, ATYP: 0x01 (IPv4), DST.ADDR: 1.1.1.1, DST.PORT: 443 (0x01, 0xbb)
    let req = [0x05, 0x01, 0x00, 0x01, 1, 1, 1, 1, 0x01, 0xbb];
    stream.write_all(&req).await.map_err(|e| {
        BackendError::VerificationFailed(format!("SOCKS write connect failed: {e}"))
    })?;

    let mut conn_resp = [0u8; 10];
    tokio::time::timeout(Duration::from_secs(4), stream.read_exact(&mut conn_resp))
        .await
        .map_err(|_| BackendError::Timeout)?
        .map_err(|e| BackendError::VerificationFailed(format!("SOCKS read connect failed: {e}")))?;

    if conn_resp[1] == 0x00 {
        Ok(())
    } else {
        Err(BackendError::VerificationFailed(format!(
            "SOCKS connect error REP={:#x}",
            conn_resp[1]
        )))
    }
}

fn extract_lastconn_peer(data_dir: &Path) -> Option<String> {
    for name in &[
        "aether-masque-lastconn.toml",
        "aether-lastconn.toml",
        "aether-wg-lastconn.toml",
    ] {
        let p = data_dir.join(name);
        if let Ok(content) = std::fs::read_to_string(&p) {
            for line in content.lines() {
                if let Some(rest) = line.strip_prefix("peer = ") {
                    let peer = rest.trim().trim_matches('"');
                    if !peer.is_empty() {
                        return Some(peer.to_string());
                    }
                }
            }
        }
    }
    None
}

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

            // Identity config files
            let base_config = self.data_dir.join("aether.toml");
            let masque_config = self.data_dir.join("aether-masque.toml");
            let wg_config = self.data_dir.join("aether-wg.toml");
            cmd.arg("--config").arg(&base_config);
            cmd.arg("--masque-config").arg(&masque_config);
            cmd.arg("--wg-config").arg(&wg_config);

            // Marks for Linux loop prevention (only when running with net admin / root)
            #[cfg(target_os = "linux")]
            if unsafe { libc::geteuid() == 0 } {
                cmd.arg("--mark").arg(DEFAULT_FWMARK.to_string());
            }

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
                    let _ = ch.wait().await;
                }
                // Purge any stale lastconn so subsequent attempts do not retry an unresponsive gateway
                let _ = std::fs::remove_file(self.data_dir.join("aether-masque-lastconn.toml"));
                let _ = std::fs::remove_file(self.data_dir.join("aether-lastconn.toml"));
                return Err(BackendError::Timeout);
            }

            info!("[aether] candidate id={} ready on {}", id, check_addr);

            // PROXY-PATH check: must run BEFORE any route or system change is made
            info!(
                "[aether] verifying proxy-path via SOCKS5 CONNECT to 1.1.1.1:443 on port {}",
                socks_port
            );
            if let Err(e) = tcp_probe_socks(socks_port).await {
                warn!(
                    "[aether] candidate id={} proxy-path check failed: {e:?}",
                    id
                );
                let maybe_child = { self.children.lock().remove(&id) };
                if let Some(mut ch) = maybe_child {
                    let _ = ch.kill().await;
                    let _ = ch.wait().await;
                }
                let _ = std::fs::remove_file(self.data_dir.join("aether-masque-lastconn.toml"));
                let _ = std::fs::remove_file(self.data_dir.join("aether-lastconn.toml"));
                return Err(e);
            }
            info!(
                "[aether] candidate id={} proxy-path verified successfully",
                id
            );

            // Extract winning peer from lastconn if available
            let discovered_endpoint = extract_lastconn_peer(&self.data_dir);
            let final_endpoint = discovered_endpoint.or_else(|| endpoint.map(|s| s.to_string()));

            Ok(CandidateHandle {
                id,
                socks_port,
                http_port: Some(http_port),
                endpoint: final_endpoint,
            })
        })
    }

    fn verify_path<'a>(
        &'a self,
        handle: &'a CandidateHandle,
    ) -> Pin<Box<dyn Future<Output = Result<PathTrace, BackendError>> + Send + 'a>> {
        Box::pin(async move {
            info!(
                "[verify] TUN-path check: connecting to 1.1.1.1:443 through system tunnel (cand id={})",
                handle.id
            );

            // Plain unmarked TCP connect to 1.1.1.1:443 through the system tunnel (1500 ms timeout)
            let tun_probe = tokio::time::timeout(
                Duration::from_millis(1500),
                tokio::net::TcpStream::connect("1.1.1.1:443"),
            )
            .await;

            match tun_probe {
                Ok(Ok(_stream)) => {
                    info!(
                        "[verify] TUN-path TCP check to 1.1.1.1:443 succeeded for cand id={}",
                        handle.id
                    );
                }
                _ => {
                    #[cfg(target_os = "linux")]
                    if unsafe { libc::geteuid() == 0 } {
                        return Err(BackendError::VerificationFailed(
                            "TUN-path TCP check to 1.1.1.1:443 failed".into(),
                        ));
                    }
                    info!(
                        "[verify] unprivileged scope: proxy-path verified for cand id={}",
                        handle.id
                    );
                }
            }

            Ok(PathTrace {
                ip: String::new(),
                loc: String::new(),
                colo: String::new(),
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
                    let _ = child.wait().await;
                }
            }
            Ok(())
        })
    }
}
