use serde_json::json;
use std::process::Command;
use tracing::{info, warn};

pub struct DesktopSystemProxy {
    desktop_env: String,
}

impl Default for DesktopSystemProxy {
    fn default() -> Self {
        let de = std::env::var("XDG_CURRENT_DESKTOP").unwrap_or_else(|_| "GNOME".to_string());
        Self { desktop_env: de }
    }
}

impl DesktopSystemProxy {
    pub fn enable_system_proxy(
        &self,
        http_port: u16,
        socks_port: u16,
    ) -> Result<serde_json::Value, String> {
        if self.desktop_env.to_uppercase().contains("GNOME")
            || self.desktop_env.to_uppercase().contains("UBUNTU")
        {
            let prev_mode = run_cmd("gsettings", &["get", "org.gnome.system.proxy", "mode"])
                .unwrap_or_default();

            run_cmd(
                "gsettings",
                &["set", "org.gnome.system.proxy.http", "host", "127.0.0.1"],
            )?;
            run_cmd(
                "gsettings",
                &[
                    "set",
                    "org.gnome.system.proxy.http",
                    "port",
                    &http_port.to_string(),
                ],
            )?;
            run_cmd(
                "gsettings",
                &["set", "org.gnome.system.proxy.https", "host", "127.0.0.1"],
            )?;
            run_cmd(
                "gsettings",
                &[
                    "set",
                    "org.gnome.system.proxy.https",
                    "port",
                    &http_port.to_string(),
                ],
            )?;
            run_cmd(
                "gsettings",
                &["set", "org.gnome.system.proxy.socks", "host", "127.0.0.1"],
            )?;
            run_cmd(
                "gsettings",
                &[
                    "set",
                    "org.gnome.system.proxy.socks",
                    "port",
                    &socks_port.to_string(),
                ],
            )?;
            let _ = run_cmd(
                "gsettings",
                &[
                    "set",
                    "org.gnome.system.proxy",
                    "ignore-hosts",
                    "['localhost', '127.0.0.0/8', '::1', '*.ir']",
                ],
            );
            run_cmd(
                "gsettings",
                &["set", "org.gnome.system.proxy", "mode", "manual"],
            )?;

            info!(
                "[platform/proxy] GNOME system proxy enabled on 127.0.0.1:{http_port}/{socks_port}"
            );
            Ok(json!({
                "desktop": "gnome",
                "prev_mode": prev_mode.trim(),
            }))
        } else if self.desktop_env.to_uppercase().contains("KDE") {
            let _ = run_cmd(
                "kwriteconfig6",
                &[
                    "--file",
                    "kioslaverc",
                    "--group",
                    "Proxy Settings",
                    "--key",
                    "ProxyType",
                    "1",
                ],
            );
            let _ = run_cmd(
                "kwriteconfig6",
                &[
                    "--file",
                    "kioslaverc",
                    "--group",
                    "Proxy Settings",
                    "--key",
                    "httpProxy",
                    &format!("http://127.0.0.1:{http_port}"),
                ],
            );
            let _ = run_cmd(
                "kwriteconfig6",
                &[
                    "--file",
                    "kioslaverc",
                    "--group",
                    "Proxy Settings",
                    "--key",
                    "httpsProxy",
                    &format!("http://127.0.0.1:{http_port}"),
                ],
            );
            let _ = run_cmd(
                "kwriteconfig6",
                &[
                    "--file",
                    "kioslaverc",
                    "--group",
                    "Proxy Settings",
                    "--key",
                    "socksProxy",
                    &format!("socks://127.0.0.1:{socks_port}"),
                ],
            );

            info!("[platform/proxy] KDE system proxy configured");
            Ok(json!({
                "desktop": "kde",
            }))
        } else {
            warn!(
                "[platform/proxy] unknown desktop environment {}; proxy mode unsupported",
                self.desktop_env
            );
            Err(format!(
                "Unsupported desktop environment: {}",
                self.desktop_env
            ))
        }
    }

    pub fn disable_system_proxy(
        &self,
        prev_state: Option<&serde_json::Value>,
    ) -> Result<(), String> {
        if self.desktop_env.to_uppercase().contains("GNOME")
            || self.desktop_env.to_uppercase().contains("UBUNTU")
        {
            let mode = prev_state
                .and_then(|v| v.get("prev_mode"))
                .and_then(|m| m.as_str())
                .unwrap_or("'none'");
            let mode_clean = mode.trim_matches('\'');
            let _ = run_cmd(
                "gsettings",
                &["set", "org.gnome.system.proxy", "mode", mode_clean],
            );
            info!("[platform/proxy] GNOME system proxy restored to {mode_clean}");
        } else if self.desktop_env.to_uppercase().contains("KDE") {
            let _ = run_cmd(
                "kwriteconfig6",
                &[
                    "--file",
                    "kioslaverc",
                    "--group",
                    "Proxy Settings",
                    "--key",
                    "ProxyType",
                    "0",
                ],
            );
            info!("[platform/proxy] KDE system proxy disabled");
        }
        Ok(())
    }
}

fn run_cmd(program: &str, args: &[&str]) -> Result<String, String> {
    let output = Command::new(program)
        .args(args)
        .output()
        .map_err(|e| format!("Failed to execute {program}: {e}"))?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        let err = String::from_utf8_lossy(&output.stderr).to_string();
        Err(format!(
            "Command '{program} {}' failed: {err}",
            args.join(" ")
        ))
    }
}
