use crate::prober::{select_tun_subnet_v4, TUN_IPV6_CANDIDATE};
use serde_json::json;
use std::process::Command;
use tracing::info;

pub const DEFAULT_FWMARK: u32 = 0x5a48;
pub const DEFAULT_TABLE: u32 = 100;
pub const PREF_MARK: u32 = 5100;
pub const PREF_SUPPRESS: u32 = 5101;
pub const PREF_TUNNEL: u32 = 5102;

#[derive(Debug, Clone)]
pub struct LinuxNetworkConfig {
    pub dev: String,
    pub mtu: u16,
    pub fwmark: u32,
    pub table: u32,
}

impl Default for LinuxNetworkConfig {
    fn default() -> Self {
        Self {
            dev: "zohal0".to_string(),
            mtu: 1280,
            fwmark: DEFAULT_FWMARK,
            table: DEFAULT_TABLE,
        }
    }
}

pub struct LinuxPlatform {
    config: LinuxNetworkConfig,
}

impl Default for LinuxPlatform {
    fn default() -> Self {
        Self::new(LinuxNetworkConfig::default())
    }
}

impl LinuxPlatform {
    pub fn new(config: LinuxNetworkConfig) -> Self {
        Self { config }
    }

    pub fn apply_tun_device(&self) -> Result<serde_json::Value, String> {
        let dev = &self.config.dev;
        let ipv4_subnet = select_tun_subnet_v4();

        // 1. Bring device up and set MTU
        run_cmd(
            "ip",
            &[
                "link",
                "set",
                "dev",
                dev,
                "up",
                "mtu",
                &self.config.mtu.to_string(),
            ],
        )?;

        // 2. Assign IP addresses
        let _ = run_cmd("ip", &["addr", "add", ipv4_subnet, "dev", dev]);
        let _ = run_cmd("ip", &["-6", "addr", "add", TUN_IPV6_CANDIDATE, "dev", dev]);

        info!(
            "[platform/linux] tun device {dev} configured with MTU {}",
            self.config.mtu
        );
        Ok(json!({
            "action": "tun_device",
            "dev": dev,
        }))
    }

    pub fn apply_policy_routing(&self) -> Result<serde_json::Value, String> {
        let dev = &self.config.dev;
        let t_str = self.config.table.to_string();
        let m_str = format!("{:#x}", self.config.fwmark);
        let p1 = PREF_MARK.to_string();
        let p2 = PREF_SUPPRESS.to_string();
        let p3 = PREF_TUNNEL.to_string();

        // IPv4 routes and rules
        run_cmd(
            "ip",
            &["route", "add", "default", "dev", dev, "table", &t_str],
        )?;
        run_cmd(
            "ip",
            &[
                "rule", "add", "pref", &p1, "fwmark", &m_str, "lookup", "main",
            ],
        )?;
        run_cmd(
            "ip",
            &[
                "rule",
                "add",
                "pref",
                &p2,
                "lookup",
                "main",
                "suppress_prefixlength",
                "0",
            ],
        )?;
        run_cmd("ip", &["rule", "add", "pref", &p3, "lookup", &t_str])?;

        // IPv6 routes and rules
        let _ = run_cmd(
            "ip",
            &["-6", "route", "add", "default", "dev", dev, "table", &t_str],
        );
        let _ = run_cmd(
            "ip",
            &[
                "-6", "rule", "add", "pref", &p1, "fwmark", &m_str, "lookup", "main",
            ],
        );
        let _ = run_cmd(
            "ip",
            &[
                "-6",
                "rule",
                "add",
                "pref",
                &p2,
                "lookup",
                "main",
                "suppress_prefixlength",
                "0",
            ],
        );
        let _ = run_cmd("ip", &["-6", "rule", "add", "pref", &p3, "lookup", &t_str]);

        info!("[platform/linux] policy routing applied for table {t_str} and fwmark {m_str}");

        Ok(json!({
            "action": "policy_routing",
            "dev": dev,
            "table": self.config.table,
            "fwmark": self.config.fwmark,
            "pref_mark": PREF_MARK,
            "pref_suppress": PREF_SUPPRESS,
            "pref_tunnel": PREF_TUNNEL,
        }))
    }

    pub fn apply_dns(&self, servers: &[String]) -> Result<serde_json::Value, String> {
        let dev = &self.config.dev;

        // Check if systemd-resolved is active
        let resolved_active = Command::new("systemctl")
            .args(["is-active", "--quiet", "systemd-resolved"])
            .status()
            .map(|s| s.success())
            .unwrap_or(false);

        if resolved_active {
            info!("[platform/linux] systemd-resolved active; configuring via resolvectl");
            let mut dns_args = vec!["dns", dev.as_str()];
            for s in servers {
                dns_args.push(s.as_str());
            }
            run_cmd("resolvectl", &dns_args)?;
            run_cmd("resolvectl", &["domain", dev.as_str(), "~."])?;

            Ok(json!({
                "action": "dns_resolved",
                "dev": dev,
            }))
        } else {
            info!(
                "[platform/linux] systemd-resolved inactive; using direct /etc/resolv.conf backup"
            );
            let original = std::fs::read_to_string("/etc/resolv.conf").unwrap_or_default();
            let mut new_resolv = String::new();
            for s in servers {
                new_resolv.push_str(&format!("nameserver {s}\n"));
            }
            let _ = std::fs::write("/etc/resolv.conf", new_resolv);

            Ok(json!({
                "action": "dns_resolv_conf",
                "original_content": original,
            }))
        }
    }

    pub fn revert_policy_routing(&self) -> Result<(), String> {
        let dev = &self.config.dev;
        let t_str = self.config.table.to_string();
        let p1 = PREF_MARK.to_string();
        let p2 = PREF_SUPPRESS.to_string();
        let p3 = PREF_TUNNEL.to_string();

        let _ = run_cmd("ip", &["rule", "del", "pref", &p3]);
        let _ = run_cmd("ip", &["rule", "del", "pref", &p2]);
        let _ = run_cmd("ip", &["rule", "del", "pref", &p1]);
        let _ = run_cmd(
            "ip",
            &["route", "del", "default", "dev", dev, "table", &t_str],
        );

        let _ = run_cmd("ip", &["-6", "rule", "del", "pref", &p3]);
        let _ = run_cmd("ip", &["-6", "rule", "del", "pref", &p2]);
        let _ = run_cmd("ip", &["-6", "rule", "del", "pref", &p1]);
        let _ = run_cmd(
            "ip",
            &["-6", "route", "del", "default", "dev", dev, "table", &t_str],
        );

        info!("[platform/linux] policy routing reverted");
        Ok(())
    }

    pub fn revert_dns(&self) -> Result<(), String> {
        let dev = &self.config.dev;
        let _ = run_cmd("resolvectl", &["revert", dev.as_str()]);
        info!("[platform/linux] DNS reverted");
        Ok(())
    }

    pub fn teardown_all(&self) -> Result<(), String> {
        self.revert_policy_routing()?;
        self.revert_dns()?;
        let _ = run_cmd("ip", &["link", "del", "dev", &self.config.dev]);
        info!("[platform/linux] teardown completed cleanly");
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
