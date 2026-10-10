#![cfg_attr(not(test), deny(clippy::unwrap_used, clippy::expect_used))]

pub mod backend;
pub mod cache;
pub mod ipc;
pub mod ipc_client;
pub mod journal;
pub mod ladder;
pub mod log_ring;
pub mod real_backend;
pub mod supervisor;
pub mod test_backend;

pub fn init() {}
