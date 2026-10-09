use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::fs::{self, File, OpenOptions};
use std::io::{BufRead, BufReader, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use tracing::{error, info, warn};

static NEXT_ACTION_ID: AtomicU64 = AtomicU64::new(1);

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct JournalAction {
    pub id: u64,
    pub kind: String,
    pub params: Value,
    pub undo: Value,
}

pub trait UndoHandler: Send + Sync {
    fn execute_undo(&self, action: &JournalAction) -> Result<(), String>;
}

pub struct Journal {
    path: PathBuf,
}

impl Journal {
    pub fn new(data_dir: &Path) -> std::io::Result<Self> {
        fs::create_dir_all(data_dir)?;
        let path = data_dir.join("journal.jsonl");
        Ok(Self { path })
    }

    pub fn record_action(
        &self,
        kind: impl Into<String>,
        params: Value,
        undo: Value,
    ) -> std::io::Result<JournalAction> {
        let action = JournalAction {
            id: NEXT_ACTION_ID.fetch_add(1, Ordering::Relaxed),
            kind: kind.into(),
            params,
            undo,
        };

        let mut file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(&self.path)?;

        let line = serde_json::to_string(&action)?;
        writeln!(file, "{line}")?;
        file.sync_all()?;
        Ok(action)
    }

    pub fn read_actions(&self) -> std::io::Result<Vec<JournalAction>> {
        if !self.path.exists() {
            return Ok(Vec::new());
        }

        let file = File::open(&self.path)?;
        let reader = BufReader::new(file);
        let mut actions = Vec::new();

        for line in reader.lines() {
            let line = line?;
            if line.trim().is_empty() {
                continue;
            }
            match serde_json::from_str::<JournalAction>(&line) {
                Ok(action) => actions.push(action),
                Err(e) => {
                    warn!("Corrupted line in journal ignored: {e}");
                }
            }
        }

        Ok(actions)
    }

    pub fn remove_action(&self, id: u64) -> std::io::Result<()> {
        let actions = self.read_actions()?;
        let remaining: Vec<JournalAction> = actions.into_iter().filter(|a| a.id != id).collect();

        if remaining.is_empty() {
            let _ = fs::remove_file(&self.path);
            return Ok(());
        }

        let temp_path = self.path.with_extension("tmp");
        {
            let mut file = File::create(&temp_path)?;
            for a in &remaining {
                let line = serde_json::to_string(a)?;
                writeln!(file, "{line}")?;
            }
            file.sync_all()?;
        }

        fs::rename(&temp_path, &self.path)?;
        Ok(())
    }

    pub fn clear(&self) -> std::io::Result<()> {
        if self.path.exists() {
            fs::remove_file(&self.path)?;
        }
        Ok(())
    }

    pub fn run_recovery(&self, handler: &dyn UndoHandler) -> std::io::Result<usize> {
        let actions = self.read_actions()?;
        if actions.is_empty() {
            return Ok(0);
        }

        info!(
            "[journal] recovery running for {} un-reverted actions in reverse order",
            actions.len()
        );
        let count = actions.len();

        for action in actions.iter().rev() {
            match handler.execute_undo(action) {
                Ok(_) => {
                    info!(
                        "[journal] undone action id={} kind={}",
                        action.id, action.kind
                    );
                    let _ = self.remove_action(action.id);
                }
                Err(e) => {
                    error!(
                        "[journal] undo failed for action id={} kind={}: {e}",
                        action.id, action.kind
                    );
                }
            }
        }

        let _ = self.clear();
        Ok(count)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use tempfile::tempdir;

    struct DummyUndo;
    impl UndoHandler for DummyUndo {
        fn execute_undo(&self, _action: &JournalAction) -> Result<(), String> {
            Ok(())
        }
    }

    #[test]
    fn test_journal_record_and_recovery() {
        let dir = tempdir().unwrap();
        let journal = Journal::new(dir.path()).unwrap();

        let a1 = journal
            .record_action("route", json!({"ip": "1.1.1.1"}), json!({"del": "1.1.1.1"}))
            .unwrap();
        let a2 = journal
            .record_action("dns", json!({"dev": "zohal0"}), json!({"revert": true}))
            .unwrap();

        let actions = journal.read_actions().unwrap();
        assert_eq!(actions.len(), 2);
        assert_eq!(actions[0].id, a1.id);
        assert_eq!(actions[1].id, a2.id);

        let undone = journal.run_recovery(&DummyUndo).unwrap();
        assert_eq!(undone, 2);

        let remaining = journal.read_actions().unwrap();
        assert!(remaining.is_empty());
    }
}
