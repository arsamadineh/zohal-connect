// engine/crates/zohal-platform/src/windows.rs
// Windows platform networking, Wintun adapter, IP Helper routes, DNS guard, and system proxy.
// Follows ZOHAL_SPEC Section 8.2 & Phase 4.

use serde::{Deserialize, Serialize};
use std::net::IpAddr;
use zohal_proto::constants::{
    DEFAULT_MTU, FIREWALL_RULE_GROUP, WINDOWS_ADAPTER_GUID, WINDOWS_ADAPTER_NAME,
};

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct WinInetSnapshot {
    pub proxy_enable: u32,
    pub proxy_server: String,
    pub proxy_override: String,
    pub auto_config_url: String,
}

pub struct WindowsPlatform {
    pub adapter_name: String,
    pub adapter_guid: String,
    pub mtu: u16,
}

impl Default for WindowsPlatform {
    fn default() -> Self {
        Self {
            adapter_name: WINDOWS_ADAPTER_NAME.to_string(),
            adapter_guid: WINDOWS_ADAPTER_GUID.to_string(),
            mtu: DEFAULT_MTU,
        }
    }
}

impl WindowsPlatform {
    pub fn new() -> Self {
        Self::default()
    }

    /// Generates IP Helper commands/actions for TUN bring-up:
    /// 1. Create Wintun adapter with fixed GUID
    /// 2. Assign IPv4 /30 and IPv6 /126
    /// 3. Add default split routes: 0.0.0.0/1, 128.0.0.0/1, ::/1, 8000::/1
    pub fn get_setup_routes(
        &self,
        ipv4: &str,
        ipv6: Option<&str>,
        dns_servers: &[IpAddr],
    ) -> Vec<String> {
        let mut plan = Vec::new();
        plan.push(format!(
            "wintun_create: name={} guid={}",
            self.adapter_name, self.adapter_guid
        ));
        plan.push(format!("ip_assign: {} dev={}", ipv4, self.adapter_name));
        if let Some(v6) = ipv6 {
            plan.push(format!("ip6_assign: {} dev={}", v6, self.adapter_name));
        }

        // Split default routes (wg-quick pattern for Windows)
        plan.push(format!(
            "route_add: 0.0.0.0/1 dev={} metric=1",
            self.adapter_name
        ));
        plan.push(format!(
            "route_add: 128.0.0.0/1 dev={} metric=1",
            self.adapter_name
        ));
        if ipv6.is_some() {
            plan.push(format!(
                "route6_add: ::/1 dev={} metric=1",
                self.adapter_name
            ));
            plan.push(format!(
                "route6_add: 8000::/1 dev={} metric=1",
                self.adapter_name
            ));
        }

        // DNS settings
        let dns_str = dns_servers
            .iter()
            .map(|ip| ip.to_string())
            .collect::<Vec<_>>()
            .join(",");
        plan.push(format!(
            "dns_set: dev={} servers={}",
            self.adapter_name, dns_str
        ));

        // DNS leak guard
        plan.push(format!(
            "firewall_guard: group={} dev={}",
            FIREWALL_RULE_GROUP, self.adapter_name
        ));

        plan
    }

    /// Generates teardown steps in reverse order
    pub fn get_teardown_plan(&self) -> Vec<String> {
        vec![
            format!("firewall_guard_remove: group={}", FIREWALL_RULE_GROUP),
            format!("dns_revert: dev={}", self.adapter_name),
            format!("route_del: 0.0.0.0/1 dev={}", self.adapter_name),
            format!("route_del: 128.0.0.0/1 dev={}", self.adapter_name),
            format!("route6_del: ::/1 dev={}", self.adapter_name),
            format!("route6_del: 8000::/1 dev={}", self.adapter_name),
            format!("wintun_destroy: guid={}", self.adapter_guid),
        ]
    }

    /// Plan B edge bypass routes for Cloudflare edge ranges via physical gateway
    pub fn get_plan_b_edge_routes(&self, gateway_ip: &str) -> Vec<String> {
        // Known Cloudflare edge IPv4 ranges that Aether scans
        let edge_ranges = [
            "162.159.192.0/24",
            "162.159.193.0/24",
            "162.159.195.0/24",
            "188.114.96.0/24",
            "188.114.97.0/24",
            "188.114.98.0/24",
            "188.114.99.0/24",
        ];

        edge_ranges
            .iter()
            .map(|range| format!("route_add: {} via {}", range, gateway_ip))
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::net::Ipv4Addr;

    #[test]
    fn test_windows_setup_and_teardown_plan() {
        let platform = WindowsPlatform::new();
        let dns = vec![IpAddr::V4(Ipv4Addr::new(1, 1, 1, 1))];
        let setup = platform.get_setup_routes("198.18.0.1/30", Some("fd7a:6f68:616c::1/126"), &dns);
        assert!(setup.iter().any(|s| s.contains("wintun_create")));
        assert!(setup.iter().any(|s| s.contains("0.0.0.0/1")));
        assert!(setup.iter().any(|s| s.contains("128.0.0.0/1")));
        assert!(setup.iter().any(|s| s.contains("ZohalDnsGuard")));

        let teardown = platform.get_teardown_plan();
        assert!(teardown.iter().any(|s| s.contains("firewall_guard_remove")));
        assert!(teardown.iter().any(|s| s.contains("wintun_destroy")));
    }

    #[test]
    fn test_plan_b_edge_routes() {
        let platform = WindowsPlatform::new();
        let routes = platform.get_plan_b_edge_routes("192.168.1.1");
        assert_eq!(routes.len(), 7);
        assert!(routes[0].contains("via 192.168.1.1"));
    }
}
