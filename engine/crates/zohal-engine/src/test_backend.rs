use crate::backend::{BackendError, CandidateHandle, PathTrace, TunnelBackend};
use crate::journal::Journal;
use crate::ladder::RungConfig;
use serde_json::json;
use std::future::Future;
use std::pin::Pin;
use std::sync::atomic::{AtomicBool, AtomicU64, AtomicUsize, Ordering};
use std::sync::Arc;
use std::time::Duration;
use tokio::time::sleep;

#[derive(Clone)]
pub struct FakeAetherBackend {
    next_id: Arc<AtomicU64>,
    pub active_processes: Arc<AtomicUsize>,
    pub max_concurrent_processes: Arc<AtomicUsize>,
    pub system_tunnel_active: Arc<AtomicBool>,
    pub start_delay: Duration,
    pub fail_start: Arc<AtomicBool>,
    pub fail_verify: Arc<AtomicBool>,
    pub fail_verify_times: Arc<std::sync::atomic::AtomicU32>,
}

impl Default for FakeAetherBackend {
    fn default() -> Self {
        Self::new()
    }
}

impl FakeAetherBackend {
    pub fn new() -> Self {
        Self {
            next_id: Arc::new(AtomicU64::new(1)),
            active_processes: Arc::new(AtomicUsize::new(0)),
            max_concurrent_processes: Arc::new(AtomicUsize::new(0)),
            system_tunnel_active: Arc::new(AtomicBool::new(false)),
            start_delay: Duration::from_millis(10),
            fail_start: Arc::new(AtomicBool::new(false)),
            fail_verify: Arc::new(AtomicBool::new(false)),
            fail_verify_times: Arc::new(std::sync::atomic::AtomicU32::new(0)),
        }
    }

    pub fn with_delay(delay: Duration) -> Self {
        let mut s = Self::new();
        s.start_delay = delay;
        s
    }
}

impl TunnelBackend for FakeAetherBackend {
    fn start_candidate<'a>(
        &'a self,
        _rung: &'a RungConfig,
        endpoint: Option<&'a str>,
    ) -> Pin<Box<dyn Future<Output = Result<CandidateHandle, BackendError>> + Send + 'a>> {
        Box::pin(async move {
            if self.start_delay > Duration::ZERO {
                sleep(self.start_delay).await;
            }

            if self.fail_start.load(Ordering::Relaxed) {
                return Err(BackendError::ProcessFailed(
                    "Simulated startup failure".into(),
                ));
            }

            let prev = self.active_processes.fetch_add(1, Ordering::SeqCst);
            let current = prev + 1;
            let mut max = self.max_concurrent_processes.load(Ordering::SeqCst);
            while current > max {
                match self.max_concurrent_processes.compare_exchange_weak(
                    max,
                    current,
                    Ordering::SeqCst,
                    Ordering::SeqCst,
                ) {
                    Ok(_) => break,
                    Err(actual) => max = actual,
                }
            }

            let id = self.next_id.fetch_add(1, Ordering::Relaxed);
            Ok(CandidateHandle {
                id,
                socks_port: 20000 + (id as u16),
                http_port: Some(21000 + (id as u16)),
                endpoint: endpoint.map(|s| s.to_string()),
            })
        })
    }

    fn verify_path<'a>(
        &'a self,
        _handle: &'a CandidateHandle,
    ) -> Pin<Box<dyn Future<Output = Result<PathTrace, BackendError>> + Send + 'a>> {
        Box::pin(async move {
            let should_fail = self.fail_verify.load(Ordering::Relaxed) || {
                let mut cur = self.fail_verify_times.load(Ordering::SeqCst);
                let mut decremented = false;
                while cur > 0 {
                    match self.fail_verify_times.compare_exchange_weak(
                        cur,
                        cur - 1,
                        Ordering::SeqCst,
                        Ordering::SeqCst,
                    ) {
                        Ok(_) => {
                            decremented = true;
                            break;
                        }
                        Err(actual) => cur = actual,
                    }
                }
                decremented
            };
            if should_fail {
                return Err(BackendError::VerificationFailed(
                    "Simulated trace failure".into(),
                ));
            }

            Ok(PathTrace {
                ip: "198.51.100.1".into(),
                loc: "DE".into(),
                colo: "FRA".into(),
                warp_on: true,
            })
        })
    }

    fn apply_system_tunnel<'a>(
        &'a self,
        handle: &'a CandidateHandle,
        journal: &'a Journal,
    ) -> Pin<Box<dyn Future<Output = Result<(), BackendError>> + Send + 'a>> {
        Box::pin(async move {
            let _ = journal.record_action(
                "test_tun",
                json!({"handle_id": handle.id}),
                json!({"revert_handle_id": handle.id}),
            );
            self.system_tunnel_active.store(true, Ordering::SeqCst);
            Ok(())
        })
    }

    fn teardown_system_tunnel<'a>(
        &'a self,
        journal: &'a Journal,
    ) -> Pin<Box<dyn Future<Output = Result<(), BackendError>> + Send + 'a>> {
        Box::pin(async move {
            self.system_tunnel_active.store(false, Ordering::SeqCst);
            let _ = journal.clear();
            Ok(())
        })
    }

    fn stop_candidate<'a>(
        &'a self,
        _handle: CandidateHandle,
    ) -> Pin<Box<dyn Future<Output = Result<(), BackendError>> + Send + 'a>> {
        Box::pin(async move {
            let _ = self.active_processes.fetch_sub(1, Ordering::SeqCst);
            Ok(())
        })
    }
}
