use crate::journal::Journal;
use crate::ladder::RungConfig;
use std::future::Future;
use std::pin::Pin;
use std::sync::Arc;
use zohal_proto::error::ErrorCode;

#[derive(Debug, Clone, thiserror::Error)]
pub enum BackendError {
    #[error("Deadline exceeded")]
    Timeout,
    #[error("Start process failed: {0}")]
    ProcessFailed(String),
    #[error("Port bind failure: {0}")]
    PortBind(String),
    #[error("Verification failed: {0}")]
    VerificationFailed(String),
    #[error("System configuration error: {0}")]
    SystemConfig(String),
    #[error("Engine error: {code:?}: {msg}")]
    Engine { code: ErrorCode, msg: String },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CandidateHandle {
    pub id: u64,
    pub socks_port: u16,
    pub http_port: Option<u16>,
    pub endpoint: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PathTrace {
    pub ip: String,
    pub loc: String,
    pub colo: String,
    pub warp_on: bool,
}

pub trait TunnelBackend: Send + Sync {
    fn start_candidate<'a>(
        &'a self,
        rung: &'a RungConfig,
        endpoint: Option<&'a str>,
    ) -> Pin<Box<dyn Future<Output = Result<CandidateHandle, BackendError>> + Send + 'a>>;

    fn verify_path<'a>(
        &'a self,
        handle: &'a CandidateHandle,
    ) -> Pin<Box<dyn Future<Output = Result<PathTrace, BackendError>> + Send + 'a>>;

    fn apply_system_tunnel<'a>(
        &'a self,
        handle: &'a CandidateHandle,
        journal: &'a Journal,
    ) -> Pin<Box<dyn Future<Output = Result<(), BackendError>> + Send + 'a>>;

    fn teardown_system_tunnel<'a>(
        &'a self,
        journal: &'a Journal,
    ) -> Pin<Box<dyn Future<Output = Result<(), BackendError>> + Send + 'a>>;

    fn stop_candidate<'a>(
        &'a self,
        handle: CandidateHandle,
    ) -> Pin<Box<dyn Future<Output = Result<(), BackendError>> + Send + 'a>>;
}

pub struct CompositeBackend {
    aether: Arc<dyn TunnelBackend>,
    custom: Arc<dyn TunnelBackend>,
    #[allow(dead_code)]
    settings: Arc<parking_lot::RwLock<zohal_proto::settings::Settings>>,
}

impl CompositeBackend {
    pub fn new(
        aether: Arc<dyn TunnelBackend>,
        custom: Arc<dyn TunnelBackend>,
        settings: Arc<parking_lot::RwLock<zohal_proto::settings::Settings>>,
    ) -> Self {
        Self {
            aether,
            custom,
            settings,
        }
    }
}

impl TunnelBackend for CompositeBackend {
    fn start_candidate<'a>(
        &'a self,
        rung: &'a RungConfig,
        endpoint: Option<&'a str>,
    ) -> Pin<Box<dyn Future<Output = Result<CandidateHandle, BackendError>> + Send + 'a>> {
        if matches!(rung.transport, zohal_proto::types::Transport::Vless | zohal_proto::types::Transport::Vmess) {
            self.custom.start_candidate(rung, endpoint)
        } else {
            self.aether.start_candidate(rung, endpoint)
        }
    }

    fn verify_path<'a>(
        &'a self,
        handle: &'a CandidateHandle,
    ) -> Pin<Box<dyn Future<Output = Result<PathTrace, BackendError>> + Send + 'a>> {
        if handle.id >= 1000 {
            self.custom.verify_path(handle)
        } else {
            self.aether.verify_path(handle)
        }
    }

    fn apply_system_tunnel<'a>(
        &'a self,
        handle: &'a CandidateHandle,
        journal: &'a Journal,
    ) -> Pin<Box<dyn Future<Output = Result<(), BackendError>> + Send + 'a>> {
        if handle.id >= 1000 {
            self.custom.apply_system_tunnel(handle, journal)
        } else {
            self.aether.apply_system_tunnel(handle, journal)
        }
    }

    fn teardown_system_tunnel<'a>(
        &'a self,
        journal: &'a Journal,
    ) -> Pin<Box<dyn Future<Output = Result<(), BackendError>> + Send + 'a>> {
        let custom_td = self.custom.teardown_system_tunnel(journal);
        let aether_td = self.aether.teardown_system_tunnel(journal);
        Box::pin(async move {
            let _ = custom_td.await;
            let _ = aether_td.await;
            Ok(())
        })
    }

    fn stop_candidate<'a>(
        &'a self,
        handle: CandidateHandle,
    ) -> Pin<Box<dyn Future<Output = Result<(), BackendError>> + Send + 'a>> {
        if handle.id >= 1000 {
            self.custom.stop_candidate(handle)
        } else {
            self.aether.stop_candidate(handle)
        }
    }
}
