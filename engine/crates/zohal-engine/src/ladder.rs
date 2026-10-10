use std::time::Duration;
use zohal_proto::types::{ConnectionMode, NoizeProfile, ScanProfile, Transport};

pub const TOTAL_LADDER_TIMEOUT: Duration = Duration::from_secs(35);

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RungConfig {
    pub rung_number: u8,
    pub transport: Transport,
    pub scan: ScanProfile,
    pub noize: NoizeProfile,
    pub use_cache: bool,
    pub h2_proven_only: bool,
    pub fragment: bool,
    pub deadline: Duration,
}

#[derive(Debug, Clone)]
pub struct Ladder {
    pub mode: ConnectionMode,
    pub rungs: Vec<RungConfig>,
    pub current_index: usize,
}

impl Ladder {
    pub fn build(mode: ConnectionMode, skip_udp: bool, winning_rung: Option<u8>) -> Self {
        let mut rungs = match mode {
            ConnectionMode::Auto => vec![
                RungConfig {
                    rung_number: 1,
                    transport: Transport::Masque2,
                    scan: ScanProfile::Turbo,
                    noize: NoizeProfile::Firewall,
                    use_cache: true,
                    h2_proven_only: true,
                    fragment: true,
                    deadline: Duration::from_secs(4),
                },
                RungConfig {
                    rung_number: 2,
                    transport: Transport::Masque3,
                    scan: ScanProfile::Turbo,
                    noize: NoizeProfile::Firewall,
                    use_cache: true,
                    h2_proven_only: false,
                    fragment: false,
                    deadline: Duration::from_secs(4),
                },
                RungConfig {
                    rung_number: 3,
                    transport: Transport::Masque2,
                    scan: ScanProfile::Balanced,
                    noize: NoizeProfile::Gfw,
                    use_cache: false,
                    h2_proven_only: false,
                    fragment: true,
                    deadline: Duration::from_secs(6),
                },
                RungConfig {
                    rung_number: 4,
                    transport: Transport::Masque3,
                    scan: ScanProfile::Balanced,
                    noize: NoizeProfile::Gfw,
                    use_cache: false,
                    h2_proven_only: false,
                    fragment: false,
                    deadline: Duration::from_secs(6),
                },
                RungConfig {
                    rung_number: 5,
                    transport: Transport::WireGuard,
                    scan: ScanProfile::Balanced,
                    noize: NoizeProfile::Balanced,
                    use_cache: false,
                    h2_proven_only: false,
                    fragment: false,
                    deadline: Duration::from_secs(8),
                },
                RungConfig {
                    rung_number: 6,
                    transport: Transport::GoolMasque,
                    scan: ScanProfile::Thorough,
                    noize: NoizeProfile::Aggressive,
                    use_cache: false,
                    h2_proven_only: false,
                    fragment: false,
                    deadline: Duration::from_secs(10),
                },
            ],
            ConnectionMode::Masque3 => vec![
                RungConfig {
                    rung_number: 1,
                    transport: Transport::Masque3,
                    scan: ScanProfile::Turbo,
                    noize: NoizeProfile::Firewall,
                    use_cache: true,
                    h2_proven_only: false,
                    fragment: false,
                    deadline: Duration::from_secs(4),
                },
                RungConfig {
                    rung_number: 2,
                    transport: Transport::Masque3,
                    scan: ScanProfile::Balanced,
                    noize: NoizeProfile::Gfw,
                    use_cache: false,
                    h2_proven_only: false,
                    fragment: false,
                    deadline: Duration::from_secs(8),
                },
                RungConfig {
                    rung_number: 3,
                    transport: Transport::Masque3,
                    scan: ScanProfile::Thorough,
                    noize: NoizeProfile::Gfw,
                    use_cache: false,
                    h2_proven_only: false,
                    fragment: false,
                    deadline: Duration::from_secs(12),
                },
            ],
            ConnectionMode::Masque2 => vec![
                RungConfig {
                    rung_number: 1,
                    transport: Transport::Masque2,
                    scan: ScanProfile::Turbo,
                    noize: NoizeProfile::Firewall,
                    use_cache: true,
                    h2_proven_only: true,
                    fragment: false,
                    deadline: Duration::from_secs(5),
                },
                RungConfig {
                    rung_number: 2,
                    transport: Transport::Masque2,
                    scan: ScanProfile::Balanced,
                    noize: NoizeProfile::Gfw,
                    use_cache: false,
                    h2_proven_only: false,
                    fragment: false,
                    deadline: Duration::from_secs(8),
                },
                RungConfig {
                    rung_number: 3,
                    transport: Transport::Masque2,
                    scan: ScanProfile::Balanced,
                    noize: NoizeProfile::Gfw,
                    use_cache: false,
                    h2_proven_only: false,
                    fragment: true,
                    deadline: Duration::from_secs(8),
                },
                RungConfig {
                    rung_number: 4,
                    transport: Transport::Masque2,
                    scan: ScanProfile::Thorough,
                    noize: NoizeProfile::Gfw,
                    use_cache: false,
                    h2_proven_only: false,
                    fragment: true,
                    deadline: Duration::from_secs(12),
                },
            ],
            ConnectionMode::WireGuard => vec![
                RungConfig {
                    rung_number: 1,
                    transport: Transport::WireGuard,
                    scan: ScanProfile::Balanced,
                    noize: NoizeProfile::Balanced,
                    use_cache: false,
                    h2_proven_only: false,
                    fragment: false,
                    deadline: Duration::from_secs(8),
                },
                RungConfig {
                    rung_number: 2,
                    transport: Transport::WireGuard,
                    scan: ScanProfile::Thorough,
                    noize: NoizeProfile::Aggressive,
                    use_cache: false,
                    h2_proven_only: false,
                    fragment: false,
                    deadline: Duration::from_secs(12),
                },
            ],
            ConnectionMode::Gool => vec![
                RungConfig {
                    rung_number: 1,
                    transport: Transport::GoolMasque,
                    scan: ScanProfile::Thorough,
                    noize: NoizeProfile::Aggressive,
                    use_cache: false,
                    h2_proven_only: false,
                    fragment: false,
                    deadline: Duration::from_secs(12),
                },
                RungConfig {
                    rung_number: 2,
                    transport: Transport::GoolClassic,
                    scan: ScanProfile::Thorough,
                    noize: NoizeProfile::Aggressive,
                    use_cache: false,
                    h2_proven_only: false,
                    fragment: false,
                    deadline: Duration::from_secs(12),
                },
            ],
        };

        if skip_udp && mode == ConnectionMode::Auto {
            rungs.retain(|r| {
                r.transport != Transport::Masque3 && r.transport != Transport::WireGuard
            });
        }

        // If a winning rung is remembered, prioritize it by rotating/moving to front if present
        if let Some(win) = winning_rung {
            if let Some(pos) = rungs.iter().position(|r| r.rung_number == win) {
                let winning = rungs.remove(pos);
                rungs.insert(0, winning);
            }
        }

        Self {
            mode,
            rungs,
            current_index: 0,
        }
    }

    pub fn next_rung(&mut self) -> Option<&RungConfig> {
        if self.current_index < self.rungs.len() {
            let item = &self.rungs[self.current_index];
            self.current_index += 1;
            Some(item)
        } else {
            None
        }
    }

    pub fn peek_current(&self) -> Option<&RungConfig> {
        self.rungs.get(self.current_index)
    }

    pub fn reset(&mut self) {
        self.current_index = 0;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_auto_ladder_normal() {
        let ladder = Ladder::build(ConnectionMode::Auto, false, None);
        assert_eq!(ladder.rungs.len(), 6);
        assert_eq!(ladder.rungs[0].rung_number, 1);
        assert_eq!(ladder.rungs[0].transport, Transport::Masque2);
        assert_eq!(ladder.rungs[1].rung_number, 2);
        assert_eq!(ladder.rungs[1].transport, Transport::Masque3);
    }

    #[test]
    fn test_auto_ladder_skip_udp() {
        let ladder = Ladder::build(ConnectionMode::Auto, true, None);
        // Masque3 (rungs 1 & 3) and WireGuard (rung 5) skipped
        for r in &ladder.rungs {
            assert_ne!(r.transport, Transport::Masque3);
            assert_ne!(r.transport, Transport::WireGuard);
        }
    }

    #[test]
    fn test_winning_rung_priority() {
        let ladder = Ladder::build(ConnectionMode::Auto, false, Some(4));
        assert_eq!(ladder.rungs[0].rung_number, 4);
    }
}
