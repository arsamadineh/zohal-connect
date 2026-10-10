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
pub enum Scope {
    Tun,
    SystemProxy,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum IpVersion {
    Auto,
    V4,
    V6,
    Dual,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum ScanProfile {
    Auto,
    Turbo,
    Balanced,
    Thorough,
    Verified,
    Ironclad,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum NoizeProfile {
    Auto,
    Off,
    Light,
    Balanced,
    Aggressive,
    Firewall,
    Gfw,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum ConnectionMode {
    Auto,
    Masque3,
    Masque2,
    WireGuard,
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
