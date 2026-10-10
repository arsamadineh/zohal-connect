use crate::backend::{BackendError, CandidateHandle, PathTrace, TunnelBackend};
use crate::cache::CacheManager;
use crate::journal::Journal;
use crate::ladder::{Ladder, RungConfig, TOTAL_LADDER_TIMEOUT};
use crate::log_ring::LogRingBuffer;
use std::sync::Arc;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use tokio::sync::watch;
use tokio::time::sleep;
use tracing::{error, info, warn};
use zohal_proto::error::ErrorCode;
use zohal_proto::settings::Settings;
use zohal_proto::types::{DesiredIntent, DesiredState, EngineState, Phase, Stage, Transport};

const SETTLE_WINDOW_MS: u64 = 120;

pub struct Supervisor {
    state_tx: watch::Sender<EngineState>,
    desired_rx: watch::Receiver<DesiredState>,
    backend: Arc<dyn TunnelBackend>,
    journal: Arc<Journal>,
    cache: Arc<CacheManager>,
    log_ring: LogRingBuffer,
    settings: Arc<parking_lot::RwLock<Settings>>,
    active_candidate: Option<CandidateHandle>,
}

impl Supervisor {
    pub fn new(
        initial_desired: DesiredState,
        backend: Arc<dyn TunnelBackend>,
        journal: Arc<Journal>,
        cache: Arc<CacheManager>,
        log_ring: LogRingBuffer,
        settings: Arc<parking_lot::RwLock<Settings>>,
    ) -> (
        Self,
        watch::Receiver<EngineState>,
        watch::Sender<DesiredState>,
    ) {
        let (state_tx, state_rx) = watch::channel(EngineState::default());
        let (desired_tx, desired_rx) = watch::channel(initial_desired);

        let sup = Self {
            state_tx,
            desired_rx,
            backend,
            journal,
            cache,
            log_ring,
            settings,
            active_candidate: None,
        };

        (sup, state_rx, desired_tx)
    }

    fn update_state<F>(&mut self, mutate: F)
    where
        F: FnOnce(&mut EngineState),
    {
        let mut curr = self.state_tx.borrow().clone();
        let prev_phase = curr.phase;
        mutate(&mut curr);
        let new_phase = curr.phase;

        if prev_phase != new_phase {
            let ts = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap_or(Duration::ZERO)
                .as_secs() as i64;
            self.log_ring.push_transition(
                ts,
                &format!("{prev_phase:?}"),
                &format!("{new_phase:?}"),
                curr.error,
            );
        }

        let _ = self.state_tx.send(curr);
    }

    pub async fn run_reconcile_loop(&mut self) {
        loop {
            let desired = *self.desired_rx.borrow();
            let current_phase = self.state_tx.borrow().phase;

            let needs_bring_up = desired.intent == DesiredIntent::Up
                && (current_phase == Phase::Idle || current_phase == Phase::Failed);

            let needs_tear_down =
                desired.intent == DesiredIntent::Down && current_phase != Phase::Idle;

            if needs_bring_up {
                // Settle window: wait 120 ms for desired to stay stable
                let mut changed = false;
                tokio::select! {
                    _ = sleep(Duration::from_millis(SETTLE_WINDOW_MS)) => {}
                    res = self.desired_rx.changed() => {
                        if res.is_ok() {
                            changed = true;
                        }
                    }
                }

                if changed {
                    continue;
                }

                // Race bring_up with desired_rx.changed()
                let mut desired_rx_race = self.desired_rx.clone();
                tokio::select! {
                    _ = self.bring_up() => {}
                    _ = desired_rx_race.changed() => {
                        info!("[supervisor] desired changed during bring_up; interrupting");
                        self.tear_down().await;
                    }
                }
            } else if needs_tear_down {
                // tear_down is never interrupted; fast and idempotent
                self.tear_down().await;
            } else {
                // Nothing to do; wait for desired to change
                if self.desired_rx.changed().await.is_err() {
                    info!("[supervisor] desired channel closed, exiting reconcile loop");
                    break;
                }
            }
        }
    }

    async fn bring_up(&mut self) {
        info!("[supervisor] bring_up starting");

        // 1. Prepare stage
        self.update_state(|s| {
            s.phase = Phase::Preparing;
            s.stage = Stage::Prepare;
            s.error = None;
        });

        // Small prepare pause to verify journal and initial environment
        sleep(Duration::from_millis(20)).await;

        let mode = self.settings.read().connection_mode;
        let fp = self.cache.compute_fingerprint("default", "10.0.0.1");
        let winning_rung = self.cache.get_winning_rung(&fp);
        let mut ladder = Ladder::build(mode, false, winning_rung);

        self.update_state(|s| {
            s.phase = Phase::Connecting;
            s.stage = Stage::FindGateway;
        });

        let start_time = Instant::now();
        let mut success = false;

        while let Some(rung) = ladder.next_rung() {
            if start_time.elapsed() >= TOTAL_LADDER_TIMEOUT {
                warn!("[supervisor] total ladder timeout exceeded");
                break;
            }

            if self.desired_rx.borrow().intent == DesiredIntent::Down {
                info!("[supervisor] aborting ladder: desired changed to Down");
                self.tear_down().await;
                return;
            }

            let rung_config = rung.clone();
            self.update_state(|s| {
                s.rung = rung_config.rung_number;
                s.transport = rung_config.transport;
                s.stage = Stage::FindGateway;
            });

            match self.try_rung(&rung_config, &fp).await {
                Ok((cand, trace)) => {
                    info!("[supervisor] rung {} succeeded!", rung_config.rung_number);
                    let _ = self.cache.record_winning_rung(&fp, rung_config.rung_number);
                    self.active_candidate = Some(cand);

                    let now = SystemTime::now()
                        .duration_since(UNIX_EPOCH)
                        .unwrap_or(Duration::ZERO)
                        .as_secs() as i64;

                    self.update_state(|s| {
                        s.phase = Phase::Connected;
                        s.stage = Stage::None;
                        s.exit_ip = Some(trace.ip);
                        s.exit_loc = Some(trace.loc);
                        s.colo = Some(trace.colo);
                        s.since_unix = Some(now);
                        s.fail_streak = 0;
                    });
                    success = true;
                    break;
                }
                Err(err) => {
                    warn!(
                        "[supervisor] rung {} failed: {err:?}",
                        rung_config.rung_number
                    );
                }
            }
        }

        if !success {
            error!("[supervisor] all rungs exhausted, entering Failed phase");
            self.update_state(|s| {
                s.phase = Phase::Failed;
                s.stage = Stage::None;
                s.error = Some(ErrorCode::E120);
                s.fail_streak += 1;
            });
        }
    }

    async fn try_rung(
        &mut self,
        rung: &RungConfig,
        _fp: &str,
    ) -> Result<(CandidateHandle, PathTrace), BackendError> {
        let deadline = rung.deadline;

        let t0 = Instant::now();
        let start_fut = self.backend.start_candidate(rung, None);
        let cand = tokio::time::timeout(deadline, start_fut)
            .await
            .map_err(|_| BackendError::Timeout)??;
        let t_gateway = t0.elapsed();

        self.update_state(|s| {
            s.stage = Stage::BuildTunnel;
            s.gateway = cand.endpoint.clone();
        });

        let t1 = Instant::now();
        if let Err(e) = self.backend.apply_system_tunnel(&cand, &self.journal).await {
            let _ = self.backend.stop_candidate(cand).await;
            return Err(e);
        }
        let t_build = t1.elapsed();

        self.update_state(|s| {
            s.stage = Stage::VerifyPath;
        });

        let t2 = Instant::now();
        let verify_fut = self.backend.verify_path(&cand);
        let trace = match tokio::time::timeout(Duration::from_secs(8), verify_fut).await {
            Ok(Ok(t)) => t,
            Ok(Err(e)) => {
                let _ = self.backend.teardown_system_tunnel(&self.journal).await;
                let _ = self.backend.stop_candidate(cand).await;
                return Err(e);
            }
            Err(_) => {
                let _ = self.backend.teardown_system_tunnel(&self.journal).await;
                let _ = self.backend.stop_candidate(cand).await;
                return Err(BackendError::Timeout);
            }
        };
        let t_verify = t2.elapsed();
        let t_total = t0.elapsed();

        info!(
            "[timeline] rung {}: find_gateway={}ms build_tunnel={}ms verify_path={}ms total={}ms",
            rung.rung_number,
            t_gateway.as_millis(),
            t_build.as_millis(),
            t_verify.as_millis(),
            t_total.as_millis()
        );

        Ok((cand, trace))
    }

    pub async fn tear_down(&mut self) {
        info!("[supervisor] tear_down starting");
        self.update_state(|s| {
            s.phase = Phase::Disconnecting;
            s.stage = Stage::None;
        });

        if let Some(cand) = self.active_candidate.take() {
            let _ = self.backend.stop_candidate(cand).await;
        }

        let _ = self.backend.teardown_system_tunnel(&self.journal).await;
        let _ = self.journal.clear();

        self.update_state(|s| {
            s.phase = Phase::Idle;
            s.stage = Stage::None;
            s.transport = Transport::None;
            s.rung = 0;
            s.gateway = None;
            s.exit_ip = None;
            s.exit_loc = None;
            s.colo = None;
            s.since_unix = None;
        });
        info!("[supervisor] tear_down completed");
    }
}
