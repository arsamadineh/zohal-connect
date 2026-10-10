use crate::error::ErrorCode;
use crate::settings::Settings;
use crate::types::{EngineState, TrafficStats};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "t", rename_all = "snake_case")]
pub enum ClientMessage {
    Hello { proto: u32, client: String },
    SetDesired { up: bool, epoch: u64 },
    GetState,
    Subscribe { stats: bool },
    Unsubscribe,
    GetSettings,
    PatchSettings { settings: Box<Settings> },
    ProbeNow,
    ExportDiagnostics,
    ResetIdentity,
    Ping,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "t", rename_all = "snake_case")]
pub enum ServerMessage {
    Hello {
        proto: u32,
        server: String,
        caps: Vec<String>,
    },
    State {
        state: Box<EngineState>,
    },
    Settings {
        settings: Box<Settings>,
    },
    Stats {
        stats: TrafficStats,
    },
    Log {
        ts: i64,
        level: String,
        code: Option<ErrorCode>,
        msg: String,
    },
    Notice {
        code: ErrorCode,
        params: HashMap<String, String>,
    },
    Error {
        code: ErrorCode,
        msg: String,
    },
    Diagnostics {
        data: String,
    },
    Pong,
}

impl ClientMessage {
    pub fn to_line(&self) -> Result<String, serde_json::Error> {
        let mut s = serde_json::to_string(self)?;
        s.push('\n');
        Ok(s)
    }

    pub fn from_line(line: &str) -> Result<Self, serde_json::Error> {
        serde_json::from_str(line.trim())
    }
}

impl ServerMessage {
    pub fn to_line(&self) -> Result<String, serde_json::Error> {
        let mut s = serde_json::to_string(self)?;
        s.push('\n');
        Ok(s)
    }

    pub fn from_line(line: &str) -> Result<Self, serde_json::Error> {
        serde_json::from_str(line.trim())
    }
}
