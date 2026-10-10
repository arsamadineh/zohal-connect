// engine/crates/zohal-bridge/src/lib.rs
// Bridge between Flutter UI and Zohal Engine according to ZOHAL_SPEC Section 6.4 & 12.3.

use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use tokio::sync::Mutex;
use zohal_engine::ipc_client::IpcClient;
use zohal_proto::ipc::{ClientMessage, ServerMessage};
use zohal_proto::types::EngineState;

pub struct BridgeClient {
    client: Arc<Mutex<Option<IpcClient>>>,
}

impl Default for BridgeClient {
    fn default() -> Self {
        Self::new()
    }
}

impl BridgeClient {
    pub fn new() -> Self {
        Self {
            client: Arc::new(Mutex::new(None)),
        }
    }

    pub async fn connect(&self, socket_path: Option<&str>) -> Result<(), String> {
        let default_path = if cfg!(target_os = "windows") {
            r"\\.\pipe\zohal-engine"
        } else {
            "/run/zohal/engine.sock"
        };
        let path_str = socket_path.unwrap_or(default_path);
        let path = Path::new(path_str);

        match IpcClient::connect(path).await {
            Ok(c) => {
                let mut guard = self.client.lock().await;
                *guard = Some(c);
                Ok(())
            }
            Err(e) => Err(format!(
                "Failed to connect to engine at {}: {}",
                path_str, e
            )),
        }
    }

    pub async fn set_desired(&self, up: bool, epoch: u64) -> Result<EngineState, String> {
        let mut guard = self.client.lock().await;
        if let Some(c) = guard.as_mut() {
            c.set_desired(up, epoch).await.map_err(|e| e.to_string())
        } else {
            Err("Not connected to engine".to_string())
        }
    }

    pub async fn get_state(&self) -> Result<EngineState, String> {
        let mut guard = self.client.lock().await;
        if let Some(c) = guard.as_mut() {
            c.get_state().await.map_err(|e| e.to_string())
        } else {
            Err("Not connected to engine".to_string())
        }
    }

    pub async fn probe_now(&self) -> Result<(), String> {
        let mut guard = self.client.lock().await;
        if let Some(c) = guard.as_mut() {
            c.send_cmd(&ClientMessage::ProbeNow)
                .await
                .map(|_| ())
                .map_err(|e| e.to_string())
        } else {
            Err("Not connected to engine".to_string())
        }
    }

    pub async fn reset_identity(&self) -> Result<(), String> {
        let mut guard = self.client.lock().await;
        if let Some(c) = guard.as_mut() {
            c.send_cmd(&ClientMessage::ResetIdentity)
                .await
                .map(|_| ())
                .map_err(|e| e.to_string())
        } else {
            Err("Not connected to engine".to_string())
        }
    }

    pub async fn export_diagnostics(&self) -> Result<String, String> {
        let mut guard = self.client.lock().await;
        if let Some(c) = guard.as_mut() {
            match c
                .send_cmd(&ClientMessage::ExportDiagnostics)
                .await
                .map_err(|e| e.to_string())?
            {
                ServerMessage::Diagnostics { data } => Ok(data),
                _ => Err("Unexpected response from engine".to_string()),
            }
        } else {
            Err("Not connected to engine".to_string())
        }
    }
}

/// Queries system accent color via D-Bus portal on Linux.
/// Returns (R, G, B) if available.
pub async fn get_system_accent_color() -> Option<(u8, u8, u8)> {
    #[cfg(target_os = "linux")]
    {
        if let Ok(connection) = zbus::Connection::session().await {
            let proxy_res: Result<zbus::Proxy, _> = zbus::Proxy::new(
                &connection,
                "org.freedesktop.portal.Desktop",
                "/org/freedesktop/portal/desktop",
                "org.freedesktop.portal.Settings",
            )
            .await;

            if let Ok(proxy) = proxy_res {
                let result: Result<zbus::zvariant::OwnedValue, _> = proxy
                    .call("ReadOne", &("org.freedesktop.appearance", "accent-color"))
                    .await;

                if let Ok(value) = result {
                    if let Ok(tuple) = <(f64, f64, f64)>::try_from(value) {
                        let r = (tuple.0 * 255.0).clamp(0.0, 255.0) as u8;
                        let g = (tuple.1 * 255.0).clamp(0.0, 255.0) as u8;
                        let b = (tuple.2 * 255.0).clamp(0.0, 255.0) as u8;
                        return Some((r, g, b));
                    }
                }
            }
        }
        None
    }

    #[cfg(not(target_os = "linux"))]
    {
        None
    }
}

/// Checks whether autostart is enabled on desktop.
pub fn is_autostart_enabled() -> bool {
    #[cfg(target_os = "linux")]
    {
        if let Some(config_dir) = dirs_config_dir() {
            let desktop_file = config_dir.join("autostart").join("zohal.desktop");
            return desktop_file.exists();
        }
        false
    }
    #[cfg(not(target_os = "linux"))]
    {
        false
    }
}

/// Sets desktop autostart.
pub fn set_autostart(enabled: bool) -> Result<(), String> {
    #[cfg(target_os = "linux")]
    {
        let config_dir = dirs_config_dir().ok_or("Cannot determine user config dir")?;
        let autostart_dir = config_dir.join("autostart");
        let desktop_file = autostart_dir.join("zohal.desktop");

        if enabled {
            fs::create_dir_all(&autostart_dir).map_err(|e| e.to_string())?;
            let content = "[Desktop Entry]\nType=Application\nName=Zohal\nExec=/opt/zohal/zohal\nIcon=zohal\nTerminal=false\nCategories=Network;Utility;\n";
            fs::write(&desktop_file, content).map_err(|e| e.to_string())?;
        } else if desktop_file.exists() {
            fs::remove_file(&desktop_file).map_err(|e| e.to_string())?;
        }
        Ok(())
    }
    #[cfg(not(target_os = "linux"))]
    {
        let _ = enabled;
        Ok(())
    }
}

fn dirs_config_dir() -> Option<PathBuf> {
    std::env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".config")))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_autostart_helpers() {
        let _ = is_autostart_enabled();
    }
}
