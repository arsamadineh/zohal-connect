#![cfg_attr(not(test), deny(clippy::unwrap_used, clippy::expect_used))]

pub mod prober;

#[cfg(target_os = "linux")]
pub mod linux;

pub mod proxy_only;
pub mod windows;

use zohal_proto::types::Scope;

pub trait Platform: Send + Sync {
    fn setup_tun(&self, scope: Scope) -> Result<(), String>;
    fn teardown_tun(&self) -> Result<(), String>;
}
