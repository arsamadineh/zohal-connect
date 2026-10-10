use parking_lot::RwLock;
use std::collections::VecDeque;
use std::sync::Arc;
use zohal_proto::error::ErrorCode;
use zohal_proto::settings::Settings;
use zohal_proto::types::EngineState;

const MAX_LOG_ENTRIES: usize = 2000;
const MAX_TRANSITION_ENTRIES: usize = 200;
const DIAGNOSTIC_LOG_LIMIT: usize = 500;

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct LogEntry {
    pub ts: i64,
    pub level: String,
    pub code: Option<ErrorCode>,
    pub msg: String,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct StateTransition {
    pub ts: i64,
    pub from: String,
    pub to: String,
    pub error: Option<ErrorCode>,
}

#[derive(Clone)]
pub struct LogRingBuffer {
    logs: Arc<RwLock<VecDeque<LogEntry>>>,
    transitions: Arc<RwLock<VecDeque<StateTransition>>>,
}

impl Default for LogRingBuffer {
    fn default() -> Self {
        Self::new()
    }
}

impl LogRingBuffer {
    pub fn new() -> Self {
        Self {
            logs: Arc::new(RwLock::new(VecDeque::with_capacity(MAX_LOG_ENTRIES))),
            transitions: Arc::new(RwLock::new(VecDeque::with_capacity(MAX_TRANSITION_ENTRIES))),
        }
    }

    pub fn push_log(
        &self,
        ts: i64,
        level: impl Into<String>,
        code: Option<ErrorCode>,
        msg: impl Into<String>,
    ) {
        let entry = LogEntry {
            ts,
            level: level.into(),
            code,
            msg: msg.into(),
        };

        let mut lock = self.logs.write();
        if lock.len() >= MAX_LOG_ENTRIES {
            lock.pop_front();
        }
        lock.push_back(entry);
    }

    pub fn push_transition(&self, ts: i64, from: &str, to: &str, error: Option<ErrorCode>) {
        let entry = StateTransition {
            ts,
            from: from.to_string(),
            to: to.to_string(),
            error,
        };

        let mut lock = self.transitions.write();
        if lock.len() >= MAX_TRANSITION_ENTRIES {
            lock.pop_front();
        }
        lock.push_back(entry);
    }

    pub fn get_recent_logs(&self, limit: usize) -> Vec<LogEntry> {
        let lock = self.logs.read();
        let skip = lock.len().saturating_sub(limit);
        lock.iter().skip(skip).cloned().collect()
    }

    pub fn get_transitions(&self) -> Vec<StateTransition> {
        self.transitions.read().iter().cloned().collect()
    }

    pub fn export_diagnostics(
        &self,
        app_version: &str,
        aether_version: &str,
        current_state: &EngineState,
        settings: &Settings,
        cache_stats: &str,
    ) -> String {
        let mut out = String::new();
        out.push_str("=== ZOHAL CONNECT DIAGNOSTICS REPORT ===\n");
        out.push_str(&format!("Timestamp: {}\n", chrono_now_secs()));
        out.push_str(&format!("App Version: {}\n", app_version));
        out.push_str(&format!("Aether Version: {}\n", aether_version));
        out.push_str(&format!(
            "OS / Architecture: {} / {}\n",
            std::env::consts::OS,
            std::env::consts::ARCH
        ));
        out.push_str(&format!(
            "Phase: {:?}, Stage: {:?}, Scope: {:?}\n",
            current_state.phase, current_state.stage, current_state.scope
        ));
        out.push_str(&format!(
            "Transport: {:?}, Gateway: {:?}, Exit IP: [MASKED]\n",
            current_state.transport, current_state.gateway
        ));
        out.push_str("\n--- SETTINGS SUMMARY ---\n");
        out.push_str(&format!(
            "Connection Mode: {:?}\n",
            settings.connection_mode
        ));
        out.push_str(&format!("IP Version: {:?}\n", settings.ip_version));
        out.push_str(&format!("Scan Profile: {:?}\n", settings.scan_profile));
        out.push_str(&format!("Noise Profile: {:?}\n", settings.noize_profile));
        out.push_str(&format!("Kill Switch: {}\n", settings.kill_switch));
        out.push_str(&format!(
            "Smart Domestic Direct: {}\n",
            settings.routing.smart_domestic_direct
        ));
        out.push_str(&format!("LAN Direct: {}\n", settings.routing.lan_direct));
        out.push_str(&format!(
            "Direct Rules Count: {}\n",
            settings.routing.direct_rules.len()
        ));
        out.push_str(&format!(
            "Block Rules Count: {}\n",
            settings.routing.block_rules.len()
        ));
        out.push_str(&format!(
            "DNS Servers Count: {}\n",
            settings.dns.servers.len()
        ));
        out.push_str(&format!(
            "Diagnostics Logging: {}\n",
            settings.diagnostic_log
        ));

        out.push_str("\n--- CACHE STATISTICS ---\n");
        out.push_str(cache_stats);
        out.push('\n');

        out.push_str("\n--- LAST STATE TRANSITIONS ---\n");
        for tr in self.get_transitions() {
            out.push_str(&format!(
                "[{}] {} -> {} (error: {:?})\n",
                tr.ts, tr.from, tr.to, tr.error
            ));
        }

        out.push_str("\n--- RECENT LOGS (MASKED) ---\n");
        let logs = self.get_recent_logs(DIAGNOSTIC_LOG_LIMIT);
        for l in logs {
            let masked = mask_sensitive_info(&l.msg);
            out.push_str(&format!(
                "[{}] [{}] {:?} {}\n",
                l.ts, l.level, l.code, masked
            ));
        }

        out.push_str("\n=== END OF REPORT ===\n");
        out
    }
}

fn chrono_now_secs() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or(std::time::Duration::ZERO)
        .as_secs() as i64
}

pub fn mask_sensitive_info(msg: &str) -> String {
    let mut result = String::with_capacity(msg.len());
    let words: Vec<&str> = msg.split_whitespace().collect();
    for (i, word) in words.iter().enumerate() {
        if i > 0 {
            result.push(' ');
        }
        if is_ipv4(word) || is_ipv6(word) {
            result.push_str("[IP_MASKED]");
        } else if is_domain(word) {
            result.push_str("[DOMAIN_MASKED]");
        } else {
            result.push_str(word);
        }
    }
    result
}

fn is_ipv4(word: &str) -> bool {
    let clean = word.trim_matches(|c: char| !c.is_ascii_alphanumeric() && c != '.' && c != ':');
    let host = if let Some((ip, port)) = clean.split_once(':') {
        if port.parse::<u16>().is_ok() {
            ip
        } else {
            clean
        }
    } else {
        clean
    };
    let parts: Vec<&str> = host.split('.').collect();
    if parts.len() == 4 {
        parts.iter().all(|p| p.parse::<u8>().is_ok())
    } else {
        false
    }
}

fn is_ipv6(word: &str) -> bool {
    let clean = word.trim_matches(|c: char| !c.is_ascii_hexdigit() && c != ':');
    clean.contains(':') && clean.split(':').count() >= 3
}

fn is_domain(word: &str) -> bool {
    let clean = word.trim_matches(|c: char| !c.is_ascii_alphanumeric() && c != '.' && c != ':');
    let host = if let Some((dom, port)) = clean.split_once(':') {
        if port.parse::<u16>().is_ok() {
            dom
        } else {
            clean
        }
    } else {
        clean
    };
    if host.contains('.') && !host.starts_with('.') && !host.ends_with('.') {
        let parts: Vec<&str> = host.split('.').collect();
        parts.len() >= 2
            && parts
                .iter()
                .all(|p| !p.is_empty() && p.chars().all(|c| c.is_ascii_alphanumeric() || c == '-'))
            && parts.last().map(|s| s.len() >= 2).unwrap_or(false)
            && !is_ipv4(host)
    } else {
        false
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_log_ring_buffer_capacity() {
        let ring = LogRingBuffer::new();
        for i in 0..2500 {
            ring.push_log(i as i64, "INFO", None, format!("Message {}", i));
        }
        let recent = ring.get_recent_logs(3000);
        assert_eq!(recent.len(), MAX_LOG_ENTRIES);
        assert_eq!(recent.first().unwrap().msg, "Message 500");
        assert_eq!(recent.last().unwrap().msg, "Message 2499");
    }

    #[test]
    fn test_masking() {
        let s = "Connecting to 198.51.100.4:443 via gateway.example.com or 2606:4700:4700::1111";
        let masked = mask_sensitive_info(s);
        assert!(masked.contains("[IP_MASKED]"));
        assert!(masked.contains("[DOMAIN_MASKED]"));
        assert!(!masked.contains("198.51.100.4"));
        assert!(!masked.contains("gateway.example.com"));
    }
}
