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
use tokio::net::TcpStream;
use tokio::process::Command;
use tokio::time::sleep;
use tracing::info;
use zohal_platform::linux::LinuxPlatform;
use zohal_platform::prober::probe_free_port;
use zohal_proto::settings::Settings;
use zohal_proto::types::{ConnectionMode, CustomNodeConfig};
use zohal_tun::{Tun2ProxyFrontend, TunFrontend};

pub fn find_sing_box_bin() -> Option<PathBuf> {
    if let Ok(path) = std::env::var("ZOHAL_SING_BOX_BIN") {
        let p = PathBuf::from(path);
        if p.exists() {
            return Some(p);
        }
    }
    if let Ok(exe) = std::env::current_exe() {
        if let Some(parent) = exe.parent() {
            for sub in &["sing-box", "bin/sing-box", "usr/bin/sing-box"] {
                let p = parent.join(sub);
                if p.exists() {
                    return Some(p);
                }
            }
        }
    }
    if let Ok(appdir) = std::env::var("ZOHAL_APPDIR").or_else(|_| std::env::var("APPDIR")) {
        for sub in &["usr/bin/sing-box", "bin/sing-box", "sing-box"] {
            let p = PathBuf::from(&appdir).join(sub);
            if p.exists() {
                return Some(p);
            }
        }
    }
    if let Ok(home) = std::env::var("HOME") {
        let home_p = PathBuf::from(home);
        for sub in &[
            ".local/share/v2rayN/bin/sing_box/sing-box",
            ".local/share/zohal/bin/sing-box",
            ".local/bin/sing-box",
        ] {
            let p = home_p.join(sub);
            if p.exists() {
                return Some(p);
            }
        }
    }
    for p in &[
        "/usr/local/bin/sing-box",
        "/usr/bin/sing-box",
        "/opt/zohal/sing-box",
        "/usr/lib/zohal/sing-box",
        "third_party/dist/linux-x86_64/sing-box",
    ] {
        let pb = PathBuf::from(p);
        if pb.exists() {
            return Some(pb);
        }
    }
    if let Ok(output) = std::process::Command::new("which").arg("sing-box").output() {
        if output.status.success() {
            let s = String::from_utf8_lossy(&output.stdout).trim().to_string();
            if !s.is_empty() {
                return Some(PathBuf::from(s));
            }
        }
    }
    None
}

pub struct CustomProxyBackend {
    bin_path: Option<PathBuf>,
    data_dir: PathBuf,
    platform: Arc<LinuxPlatform>,
    tun_frontend: Arc<parking_lot::Mutex<Tun2ProxyFrontend>>,
    children: Arc<parking_lot::Mutex<HashMap<u64, (tokio::process::Child, PathBuf)>>>,
    next_id: Arc<AtomicU64>,
    node_config: Arc<parking_lot::RwLock<Option<CustomNodeConfig>>>,
    settings: Option<Arc<parking_lot::RwLock<Settings>>>,
}

impl CustomProxyBackend {
    pub fn new(
        bin_path: Option<PathBuf>,
        data_dir: impl Into<PathBuf>,
        platform: Arc<LinuxPlatform>,
        tun_frontend: Arc<parking_lot::Mutex<Tun2ProxyFrontend>>,
        node_config: Arc<parking_lot::RwLock<Option<CustomNodeConfig>>>,
        settings: Option<Arc<parking_lot::RwLock<Settings>>>,
    ) -> Self {
        Self {
            bin_path,
            data_dir: data_dir.into(),
            platform,
            tun_frontend,
            children: Arc::new(parking_lot::Mutex::new(HashMap::new())),
            next_id: Arc::new(AtomicU64::new(1000)),
            node_config,
            settings,
        }
    }

    pub fn set_node_config(&self, config: Option<CustomNodeConfig>) {
        *self.node_config.write() = config;
    }

    pub fn generate_sing_box_config(
        config: &CustomNodeConfig,
        socks_port: u16,
    ) -> serde_json::Value {
        let is_vmess = config.protocol.eq_ignore_ascii_case("vmess");
        let outbound = if is_vmess {
            let mut ob = serde_json::json!({
                "type": "vmess",
                "tag": "proxy",
                "server": config.server,
                "server_port": config.port,
                "uuid": config.uuid,
                "security": "auto",
                "alter_id": 0,
            });
            if let Some(sec) = &config.security {
                if sec == "tls" {
                    ob["tls"] = serde_json::json!({
                        "enabled": true,
                        "server_name": config.sni.as_deref().unwrap_or(&config.server),
                    });
                }
            }
            if let Some(trans) = &config.transport {
                if trans == "ws" {
                    ob["transport"] = serde_json::json!({
                        "type": "ws",
                        "path": config.path.as_deref().unwrap_or("/"),
                    });
                }
            }
            ob
        } else {
            // VLESS
            let mut ob = serde_json::json!({
                "type": "vless",
                "tag": "proxy",
                "server": config.server,
                "server_port": config.port,
                "uuid": config.uuid,
            });
            if let Some(flow) = &config.flow {
                if !flow.is_empty() {
                    ob["flow"] = serde_json::json!(flow);
                }
            }
            let is_reality = config.security.as_deref() == Some("reality");
            let is_tls = is_reality || config.security.as_deref() == Some("tls");
            if is_tls {
                let mut tls_obj = serde_json::json!({
                    "enabled": true,
                    "server_name": config.sni.as_deref().unwrap_or(&config.server),
                    "utls": {
                        "enabled": true,
                        "fingerprint": config.fingerprint.as_deref().unwrap_or("chrome")
                    }
                });
                if is_reality {
                    if let Some(pbk) = &config.public_key {
                        tls_obj["reality"] = serde_json::json!({
                            "enabled": true,
                            "public_key": pbk,
                            "short_id": config.short_id.as_deref().unwrap_or("")
                        });
                    }
                }
                ob["tls"] = tls_obj;
            }
            if let Some(trans) = &config.transport {
                if trans == "ws" {
                    ob["transport"] = serde_json::json!({
                        "type": "ws",
                        "path": config.path.as_deref().unwrap_or("/"),
                    });
                } else if trans == "grpc" {
                    ob["transport"] = serde_json::json!({
                        "type": "grpc",
                        "service_name": config.path.as_deref().unwrap_or(""),
                    });
                }
            }
            ob
        };

        serde_json::json!({
            "log": {
                "level": "warn"
            },
            "inbounds": [
                {
                    "type": "mixed",
                    "tag": "mixed-in",
                    "listen": "127.0.0.1",
                    "listen_port": socks_port
                }
            ],
            "outbounds": [
                outbound,
                {
                    "type": "direct",
                    "tag": "direct"
                }
            ]
        })
    }
}

impl TunnelBackend for CustomProxyBackend {
    fn start_candidate<'a>(
        &'a self,
        rung: &'a RungConfig,
        _endpoint: Option<&'a str>,
    ) -> Pin<Box<dyn Future<Output = Result<CandidateHandle, BackendError>> + Send + 'a>> {
        Box::pin(async move {
            let bin = self.bin_path.as_ref().ok_or_else(|| {
                BackendError::ProcessFailed(
                    "sing-box binary not found on host. Install sing-box or place in ~/.local/share/zohal/bin/sing-box".into(),
                )
            })?;

            let config = self
                .node_config
                .read()
                .clone()
                .or_else(|| {
                    self.settings.as_ref().and_then(|s| {
                        if let ConnectionMode::Custom(ref cfg) = s.read().connection_mode {
                            Some((**cfg).clone())
                        } else {
                            None
                        }
                    })
                })
                .ok_or_else(|| {
                    BackendError::ProcessFailed("No custom node configuration provided".into())
                })?;

            let id = self.next_id.fetch_add(1, Ordering::Relaxed);
            let socks_port = probe_free_port(22000, 32000).map_err(BackendError::PortBind)?;

            let cfg_json = Self::generate_sing_box_config(&config, socks_port);
            let cfg_path = self.data_dir.join(format!("sing_box_cand_{id}.json"));
            std::fs::write(
                &cfg_path,
                serde_json::to_string_pretty(&cfg_json)
                    .map_err(|e| BackendError::ProcessFailed(e.to_string()))?,
            )
            .map_err(|e| BackendError::ProcessFailed(format!("Failed to write sing-box config: {e}")))?;

            let mut cmd = Command::new(bin);
            cmd.arg("run").arg("-c").arg(&cfg_path);
            cmd.stdin(Stdio::null());
            cmd.stdout(Stdio::piped());
            cmd.stderr(Stdio::piped());

            #[cfg(target_os = "linux")]
            unsafe {
                cmd.pre_exec(|| {
                    libc::prctl(libc::PR_SET_PDEATHSIG, libc::SIGTERM);
                    Ok(())
                });
            }

            info!("[custom_proxy] spawning sing-box candidate id={} on socks_port={}", id, socks_port);
            let child = cmd
                .spawn()
                .map_err(|e| BackendError::ProcessFailed(format!("Failed to spawn sing-box: {e}")))?;

            self.children.lock().insert(id, (child, cfg_path.clone()));

            // Wait for SOCKS readiness
            let start = std::time::Instant::now();
            let mut ready = false;
            let check_addr = format!("127.0.0.1:{socks_port}");
            while start.elapsed() < rung.deadline {
                if TcpStream::connect(&check_addr).await.is_ok() {
                    ready = true;
                    break;
                }
                sleep(Duration::from_millis(50)).await;
            }

            if !ready {
                let maybe_ch = self.children.lock().remove(&id);
                if let Some((mut ch, path)) = maybe_ch {
                    let _ = ch.kill().await;
                    let _ = ch.wait().await;
                    let _ = std::fs::remove_file(path);
                }
                return Err(BackendError::Timeout);
            }

            Ok(CandidateHandle {
                id,
                socks_port,
                http_port: Some(socks_port),
                endpoint: Some(format!("{}:{}", config.server, config.port)),
            })
        })
    }

    fn verify_path<'a>(
        &'a self,
        handle: &'a CandidateHandle,
    ) -> Pin<Box<dyn Future<Output = Result<PathTrace, BackendError>> + Send + 'a>> {
        Box::pin(async move {
            info!("[custom_proxy] verifying proxy path via SOCKS5 port {}", handle.socks_port);
            let proxy_url = format!("socks5://127.0.0.1:{}", handle.socks_port);
            let proxy_agent = ureq::Proxy::new(&proxy_url)
                .map_err(|e| BackendError::VerificationFailed(e.to_string()))?;
            let agent = ureq::builder()
                .proxy(proxy_agent)
                .timeout(Duration::from_secs(8))
                .build();

            let body = tokio::task::spawn_blocking(move || {
                agent
                    .get("https://1.1.1.1/cdn-cgi/trace")
                    .call()
                    .map_err(|e| e.to_string())
                    .and_then(|resp| resp.into_string().map_err(|e| e.to_string()))
            })
            .await
            .map_err(|e| BackendError::VerificationFailed(e.to_string()))?
            .map_err(BackendError::VerificationFailed)?;

            let mut ip = "unknown".to_string();
            let mut loc = "unknown".to_string();
            let mut colo = "unknown".to_string();
            for line in body.lines() {
                if let Some((key, value)) = line.split_once('=') {
                    match key.trim() {
                        "ip" => ip = value.trim().to_string(),
                        "loc" => loc = value.trim().to_string(),
                        "colo" => colo = value.trim().to_string(),
                        _ => {}
                    }
                }
            }

            Ok(PathTrace {
                ip,
                loc,
                colo,
                warp_on: false,
            })
        })
    }

    fn apply_system_tunnel<'a>(
        &'a self,
        handle: &'a CandidateHandle,
        journal: &'a Journal,
    ) -> Pin<Box<dyn Future<Output = Result<(), BackendError>> + Send + 'a>> {
        Box::pin(async move {
            info!("[custom_proxy] applying system tunnel on port {}", handle.socks_port);
            #[cfg(target_os = "linux")]
            if unsafe { libc::geteuid() } != 0 {
                let proxy = zohal_platform::proxy_only::DesktopSystemProxy::default();
                let prev = proxy
                    .enable_system_proxy(handle.http_port.unwrap_or(handle.socks_port), handle.socks_port)
                    .map_err(BackendError::SystemConfig)?;
                let undo = serde_json::json!({"action": "proxy_restore", "prev": prev});
                let _ = journal.record_action("system_proxy", serde_json::json!({"socks": handle.socks_port}), undo);
                return Ok(());
            }

            self.tun_frontend
                .lock()
                .start("zohal0", handle.socks_port, 1280)
                .map_err(BackendError::SystemConfig)?;
            let _ = self.platform.apply_tun_device();
            let _ = self.platform.apply_policy_routing();
            let dns = vec!["1.1.1.1".to_string(), "1.0.0.1".to_string()];
            let _ = self.platform.apply_dns(&dns);
            Ok(())
        })
    }

    fn teardown_system_tunnel<'a>(
        &'a self,
        journal: &'a Journal,
    ) -> Pin<Box<dyn Future<Output = Result<(), BackendError>> + Send + 'a>> {
        Box::pin(async move {
            info!("[custom_proxy] tearing down system tunnel");
            let _ = self.tun_frontend.lock().stop();
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
            info!("[custom_proxy] stopping candidate id={}", handle.id);
            let maybe_ch = self.children.lock().remove(&handle.id);
            if let Some((mut child, path)) = maybe_ch {
                if let Some(pid) = child.id() {
                    let _ = kill(Pid::from_raw(pid as i32), Signal::SIGTERM);
                    let mut exited = false;
                    for _ in 0..6 {
                        if child.try_wait().ok().flatten().is_some() {
                            exited = true;
                            break;
                        }
                        sleep(Duration::from_millis(50)).await;
                    }
                    if !exited {
                        let _ = child.kill().await;
                    }
                    let _ = child.wait().await;
                }
                let _ = std::fs::remove_file(path);
            }
            Ok(())
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_sing_box_config_vless_reality() {
        let node = CustomNodeConfig {
            protocol: "vless".to_string(),
            server: "1.1.1.1".to_string(),
            port: 443,
            uuid: "a3bb189e-8bf9-3888-9912-ace4e6543002".to_string(),
            security: Some("reality".to_string()),
            sni: Some("example.com".to_string()),
            transport: Some("tcp".to_string()),
            path: None,
            fingerprint: Some("chrome".to_string()),
            public_key: Some("QUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUE".to_string()),
            short_id: Some("01234567".to_string()),
            flow: Some("xtls-rprx-vision".to_string()),
        };
        let cfg = CustomProxyBackend::generate_sing_box_config(&node, 20888);
        assert_eq!(cfg["inbounds"][0]["listen_port"], 20888);
        assert_eq!(cfg["outbounds"][0]["type"], "vless");
        assert_eq!(cfg["outbounds"][0]["tls"]["enabled"], true);
        assert_eq!(
            cfg["outbounds"][0]["tls"]["reality"]["public_key"],
            "QUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUE"
        );
        assert_eq!(cfg["outbounds"][0]["flow"], "xtls-rprx-vision");

        if let Some(bin) = find_sing_box_bin() {
            let tmp = tempfile::NamedTempFile::new().unwrap();
            serde_json::to_writer_pretty(&tmp, &cfg).unwrap();
            let check_res = std::process::Command::new(bin)
                .arg("check")
                .arg("-c")
                .arg(tmp.path())
                .output()
                .unwrap();
            assert!(
                check_res.status.success(),
                "sing-box check failed: {}",
                String::from_utf8_lossy(&check_res.stderr)
            );
        }
    }

    #[test]
    fn test_generate_sing_box_config_vmess_ws() {
        let node = CustomNodeConfig {
            protocol: "vmess".to_string(),
            server: "2.2.2.2".to_string(),
            port: 8443,
            uuid: "b3bb189e-8bf9-3888-9912-ace4e6543003".to_string(),
            security: Some("tls".to_string()),
            sni: Some("ws.example.com".to_string()),
            transport: Some("ws".to_string()),
            path: Some("/ws-path".to_string()),
            fingerprint: None,
            public_key: None,
            short_id: None,
            flow: None,
        };
        let cfg = CustomProxyBackend::generate_sing_box_config(&node, 20999);
        assert_eq!(cfg["inbounds"][0]["listen_port"], 20999);
        assert_eq!(cfg["outbounds"][0]["type"], "vmess");
        assert_eq!(cfg["outbounds"][0]["transport"]["type"], "ws");
        assert_eq!(cfg["outbounds"][0]["transport"]["path"], "/ws-path");

        if let Some(bin) = find_sing_box_bin() {
            let tmp = tempfile::NamedTempFile::new().unwrap();
            serde_json::to_writer_pretty(&tmp, &cfg).unwrap();
            let check_res = std::process::Command::new(bin)
                .arg("check")
                .arg("-c")
                .arg(tmp.path())
                .output()
                .unwrap();
            assert!(
                check_res.status.success(),
                "sing-box check failed: {}",
                String::from_utf8_lossy(&check_res.stderr)
            );
        }
    }
}
