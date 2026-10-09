use std::collections::HashSet;
use std::sync::atomic::Ordering;
use std::sync::Arc;
use std::time::Duration;
use tempfile::tempdir;
use tokio::time::sleep;
use zohal_engine::cache::CacheManager;
use zohal_engine::fake_backend::FakeAetherBackend;
use zohal_engine::journal::Journal;
use zohal_engine::log_ring::LogRingBuffer;
use zohal_engine::supervisor::Supervisor;
use zohal_proto::settings::Settings;
use zohal_proto::types::{DesiredIntent, DesiredState, Phase};

#[tokio::test]
async fn test_torture_spam_clicking_quiescence_and_invariants_20_seeds() {
    for seed in 0..20 {
        let dir = tempdir().unwrap();
        let journal = Arc::new(Journal::new(dir.path()).unwrap());
        let cache = Arc::new(CacheManager::new(dir.path(), format!("test_salt_{seed}")).unwrap());
        let log_ring = LogRingBuffer::new();
        let settings = Arc::new(parking_lot::RwLock::new(Settings::default()));

        let fake_backend = Arc::new(FakeAetherBackend::with_delay(Duration::from_millis(1)));

        let initial_desired = DesiredState {
            intent: DesiredIntent::Down,
            epoch: 0,
        };

        let (mut supervisor, state_rx, desired_tx) = Supervisor::new(
            initial_desired,
            fake_backend.clone(),
            journal.clone(),
            cache.clone(),
            log_ring.clone(),
            settings.clone(),
        );

        let sup_task = tokio::spawn(async move {
            supervisor.run_reconcile_loop().await;
        });

        // 10,000 rapid toggle spam with varying intervals
        let total_toggles = 10_000;
        let mut rng_state: u64 = 0x123456789abcdef ^ (seed as u64 + 1);

        for epoch in 1..=total_toggles {
            // pseudo-random xorshift
            rng_state ^= rng_state << 13;
            rng_state ^= rng_state >> 7;
            rng_state ^= rng_state << 17;

            let up = (rng_state % 2) == 1;
            let _ = desired_tx.send(DesiredState {
                intent: if up {
                    DesiredIntent::Up
                } else {
                    DesiredIntent::Down
                },
                epoch,
            });

            if epoch % 2500 == 0 {
                sleep(Duration::from_millis(130)).await;
            } else if epoch % 500 == 0 {
                tokio::task::yield_now().await;
            }
        }

        // Final Down desired state
        let _ = desired_tx.send(DesiredState {
            intent: DesiredIntent::Down,
            epoch: total_toggles + 1,
        });

        // Wait for settle and quiescence
        let mut quiescent = false;
        for _ in 0..40 {
            sleep(Duration::from_millis(40)).await;
            if state_rx.borrow().phase == Phase::Idle {
                quiescent = true;
                break;
            }
        }
        assert!(
            quiescent,
            "Seed {seed}: failed to reach Idle. Current: {:?}",
            state_rx.borrow().phase
        );

        assert_eq!(
            fake_backend.active_processes.load(Ordering::SeqCst),
            0,
            "Seed {seed}: Leaked child processes detected!"
        );

        let max_proc = fake_backend.max_concurrent_processes.load(Ordering::SeqCst);
        assert!(
            max_proc <= 2,
            "Seed {seed}: Max concurrent was {max_proc} (must be <= 2)"
        );

        let actions = journal.read_actions().unwrap();
        assert!(
            actions.is_empty(),
            "Seed {seed}: Leaked journal entries: {}",
            actions.len()
        );

        assert!(
            !fake_backend.system_tunnel_active.load(Ordering::SeqCst),
            "Seed {seed}: Leaked system tunnel state!"
        );

        let allowed_transitions: HashSet<(&str, &str)> = [
            ("Idle", "Preparing"),
            ("Preparing", "Connecting"),
            ("Preparing", "Disconnecting"),
            ("Connecting", "Connected"),
            ("Connecting", "Reconnecting"),
            ("Connecting", "Disconnecting"),
            ("Connecting", "Failed"),
            ("Connected", "Reconnecting"),
            ("Connected", "Disconnecting"),
            ("Reconnecting", "Connected"),
            ("Reconnecting", "Disconnecting"),
            ("Reconnecting", "Failed"),
            ("Disconnecting", "Idle"),
            ("Failed", "Preparing"),
            ("Failed", "Idle"),
        ]
        .into_iter()
        .collect();

        let transitions = log_ring.get_transitions();
        for tr in &transitions {
            let pair = (tr.from.as_str(), tr.to.as_str());
            assert!(
                allowed_transitions.contains(&pair),
                "Seed {seed}: Illegal transition {} -> {}",
                tr.from,
                tr.to
            );
        }

        sup_task.abort();
    }
}
