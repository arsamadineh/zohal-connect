use std::net::{TcpListener, UdpSocket};
use std::process::Command;
use tracing::info;

pub const TUN_IPV4_CANDIDATES: &[&str] = &[
    "198.18.0.1/30",
    "198.19.0.1/30",
    "100.127.255.1/30",
    "10.255.255.1/30",
];

pub const TUN_IPV6_CANDIDATE: &str = "fd7a:6f68:616c::1/126";

pub fn probe_free_port(start_range: u16, end_range: u16) -> Result<u16, String> {
    let span = end_range.saturating_sub(start_range);
    let offset = (std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u16)
        % span.max(1);

    for i in 0..span {
        let port = start_range + ((offset + i) % span);
        // Test bind both TCP and UDP
        if let Ok(tcp) = TcpListener::bind(("127.0.0.1", port)) {
            drop(tcp);
            if let Ok(udp) = UdpSocket::bind(("127.0.0.1", port)) {
                drop(udp);
                info!("[prober] found free loopback port {port}");
                return Ok(port);
            }
        }
    }

    Err("No free port available in candidate range".into())
}

pub fn select_tun_subnet_v4() -> &'static str {
    // Check existing ip addresses using ip -o addr
    let output = Command::new("ip").args(["-o", "addr"]).output();
    let existing = match output {
        Ok(out) => String::from_utf8_lossy(&out.stdout).to_string(),
        Err(_) => String::new(),
    };

    for candidate in TUN_IPV4_CANDIDATES {
        let prefix = candidate.split('/').next().unwrap_or("");
        if !existing.contains(prefix) {
            info!("[prober] selected non-overlapping TUN IPv4 subnet {candidate}");
            return candidate;
        }
    }

    TUN_IPV4_CANDIDATES[0]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_probe_free_port() {
        let p = probe_free_port(25000, 35000).unwrap();
        assert!((25000..35000).contains(&p));
    }

    #[test]
    fn test_select_tun_subnet() {
        let sub = select_tun_subnet_v4();
        assert!(sub.contains("/30"));
    }
}
