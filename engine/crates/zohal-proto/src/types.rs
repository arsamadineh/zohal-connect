use crate::error::ErrorCode;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum Phase {
    Idle,
    Preparing,
    Connecting,
    Connected,
    Reconnecting,
    Disconnecting,
    Failed,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum Stage {
    None,
    Prepare,
    FindGateway,
    BuildTunnel,
    VerifyPath,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum DesiredIntent {
    Up,
    Down,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct DesiredState {
    pub intent: DesiredIntent,
    pub epoch: u64,
}

impl Default for DesiredState {
    fn default() -> Self {
        Self {
            intent: DesiredIntent::Down,
            epoch: 0,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum Transport {
    None,
    Masque3,
    Masque2,
    WireGuard,
    GoolMasque,
    GoolClassic,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")]
pub enum Scope {
    #[serde(alias = "tun")]
    Tun,
    #[serde(alias = "system_proxy", alias = "systemproxy", alias = "systemProxy")]
    SystemProxy,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")]
pub enum IpVersion {
    #[serde(alias = "auto")]
    Auto,
    #[serde(alias = "v4", alias = "ipv4")]
    V4,
    #[serde(alias = "v6", alias = "ipv6")]
    V6,
    #[serde(alias = "dual")]
    Dual,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")]
pub enum ScanProfile {
    #[serde(alias = "auto")]
    Auto,
    #[serde(alias = "turbo")]
    Turbo,
    #[serde(alias = "balanced")]
    Balanced,
    #[serde(alias = "thorough")]
    Thorough,
    #[serde(alias = "verified")]
    Verified,
    #[serde(alias = "ironclad")]
    Ironclad,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")]
pub enum NoizeProfile {
    #[serde(alias = "auto")]
    Auto,
    #[serde(alias = "off")]
    Off,
    #[serde(alias = "light")]
    Light,
    #[serde(alias = "balanced")]
    Balanced,
    #[serde(alias = "aggressive")]
    Aggressive,
    #[serde(alias = "firewall")]
    Firewall,
    #[serde(alias = "gfw")]
    Gfw,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")]
pub enum ConnectionMode {
    #[serde(alias = "auto")]
    Auto,
    #[serde(alias = "masque3", alias = "masque_3")]
    Masque3,
    #[serde(alias = "masque2", alias = "masque_2")]
    Masque2,
    #[serde(alias = "wireguard", alias = "wire_guard")]
    WireGuard,
    #[serde(alias = "gool")]
    Gool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EngineState {
    pub phase: Phase,
    pub stage: Stage,
    pub desired: DesiredState,
    pub transport: Transport,
    pub rung: u8,
    pub attempt: u32,
    pub gateway: Option<String>,
    pub exit_ip: Option<String>,
    pub exit_loc: Option<String>,
    pub colo: Option<String>,
    pub since_unix: Option<i64>,
    pub error: Option<ErrorCode>,
    pub fail_streak: u32,
    pub scope: Scope,
    pub kill_switch_engaged: bool,
}

impl Default for EngineState {
    fn default() -> Self {
        Self {
            phase: Phase::Idle,
            stage: Stage::None,
            desired: DesiredState::default(),
            transport: Transport::None,
            rung: 0,
            attempt: 0,
            gateway: None,
            exit_ip: None,
            exit_loc: None,
            colo: None,
            since_unix: None,
            error: None,
            fail_streak: 0,
            scope: Scope::Tun,
            kill_switch_engaged: false,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct TrafficStats {
    pub rx_bps: u64,
    pub tx_bps: u64,
    pub rx_total: u64,
    pub tx_total: u64,
}
