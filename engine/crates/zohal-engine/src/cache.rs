use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::fs::{self, File};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tracing::warn;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CachedGateway {
    pub endpoint: String,
    pub rtt_ms: u32,
    pub last_success_unix: u64,
    pub failure_count: u32,
    pub cooldown_until_unix: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct EndpointsCache {
    pub by_fingerprint: HashMap<String, Vec<CachedGateway>>,
    pub global_fallbacks: Vec<CachedGateway>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WinningRung {
    pub rung: u8,
    pub updated_unix: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct RungsCache {
    pub winning_rungs: HashMap<String, WinningRung>,
}

pub struct CacheManager {
    data_dir: PathBuf,
    salt: String,
}

impl CacheManager {
    pub fn new(data_dir: &Path, salt: impl Into<String>) -> std::io::Result<Self> {
        fs::create_dir_all(data_dir)?;
        Ok(Self {
            data_dir: data_dir.to_path_buf(),
            salt: salt.into(),
        })
    }

    pub fn compute_fingerprint(&self, transport_kind: &str, default_gateway_ip: &str) -> String {
        let mut hasher = Sha256::new();
        hasher.update(self.salt.as_bytes());
        hasher.update(b"|");
        hasher.update(transport_kind.as_bytes());
        hasher.update(b"|");
        hasher.update(default_gateway_ip.as_bytes());
        let hash = hasher.finalize();
        let mut bytes = [0u8; 8];
        bytes.copy_from_slice(&hash[..8]);
        format!("{:016x}", u64::from_be_bytes(bytes))
    }

    pub fn load_endpoints(&self) -> EndpointsCache {
        let path = self.data_dir.join("endpoints.json");
        Self::load_json_with_recovery(&path).unwrap_or_default()
    }

    pub fn save_endpoints(&self, endpoints: &EndpointsCache) -> std::io::Result<()> {
        let path = self.data_dir.join("endpoints.json");
        Self::atomic_write_json(&path, endpoints)
    }

    pub fn load_rungs(&self) -> RungsCache {
        let path = self.data_dir.join("rungs.json");
        Self::load_json_with_recovery(&path).unwrap_or_default()
    }

    pub fn save_rungs(&self, rungs: &RungsCache) -> std::io::Result<()> {
        let path = self.data_dir.join("rungs.json");
        Self::atomic_write_json(&path, rungs)
    }

    pub fn record_winning_rung(&self, fingerprint: &str, rung: u8) -> std::io::Result<()> {
        let mut cache = self.load_rungs();
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or(Duration::ZERO)
            .as_secs();

        cache.winning_rungs.insert(
            fingerprint.to_string(),
            WinningRung {
                rung,
                updated_unix: now,
            },
        );
        self.save_rungs(&cache)
    }

    pub fn get_winning_rung(&self, fingerprint: &str) -> Option<u8> {
        let cache = self.load_rungs();
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or(Duration::ZERO)
            .as_secs();

        if let Some(entry) = cache.winning_rungs.get(fingerprint) {
            // TTL 7 days (7 * 86400 = 604,800 s)
            if now.saturating_sub(entry.updated_unix) <= 7 * 86400 {
                return Some(entry.rung);
            }
        }
        None
    }

    fn load_json_with_recovery<T: for<'a> Deserialize<'a>>(path: &Path) -> Option<T> {
        if !path.exists() {
            return None;
        }

        let content = match fs::read_to_string(path) {
            Ok(c) => c,
            Err(e) => {
                warn!("Cannot read cache file {:?}: {e}", path);
                return None;
            }
        };

        match serde_json::from_str::<T>(&content) {
            Ok(val) => Some(val),
            Err(err) => {
                warn!("Cache file {:?} corrupt ({err}); moving to .corrupt", path);
                let corrupt_path = path.with_extension("json.corrupt");
                let _ = fs::rename(path, corrupt_path);
                None
            }
        }
    }

    fn atomic_write_json<T: Serialize>(path: &Path, value: &T) -> std::io::Result<()> {
        let temp_path = path.with_extension("tmp");
        let content = serde_json::to_string_pretty(value)?;
        {
            let mut file = File::create(&temp_path)?;
            file.write_all(content.as_bytes())?;
            file.sync_all()?;
        }
        fs::rename(temp_path, path)?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn test_cache_atomic_io_and_recovery() {
        let dir = tempdir().unwrap();
        let mgr = CacheManager::new(dir.path(), "test-salt-123").unwrap();

        let fp = mgr.compute_fingerprint("wifi", "192.168.1.1");
        assert_eq!(fp.len(), 16);

        mgr.record_winning_rung(&fp, 2).unwrap();
        assert_eq!(mgr.get_winning_rung(&fp), Some(2));

        // Corrupt file test
        let rungs_path = dir.path().join("rungs.json");
        fs::write(&rungs_path, "{invalid_json").unwrap();

        // Must recover without panic
        assert_eq!(mgr.get_winning_rung(&fp), None);
        assert!(dir.path().join("rungs.json.corrupt").exists());
    }
}
