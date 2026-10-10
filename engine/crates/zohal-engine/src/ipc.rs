use crate::log_ring::LogRingBuffer;
use interprocess::local_socket::tokio::prelude::*;
use interprocess::local_socket::tokio::Stream;
use interprocess::local_socket::{GenericFilePath, ListenerOptions, ToFsName};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt as TokioAsyncWriteExt, BufReader};
use tokio::sync::watch;
use tokio::time::sleep;
use tracing::{error, info, warn};
use zohal_proto::constants::PROTOCOL_VERSION;
use zohal_proto::error::ErrorCode;
use zohal_proto::ipc::{ClientMessage, ServerMessage};
use zohal_proto::settings::Settings;
use zohal_proto::types::{DesiredIntent, DesiredState, EngineState};

pub struct IpcServer {
    socket_path: PathBuf,
    state_rx: watch::Receiver<EngineState>,
    desired_tx: watch::Sender<DesiredState>,
    settings: Arc<parking_lot::RwLock<Settings>>,
    log_ring: LogRingBuffer,
}

impl IpcServer {
    pub fn new(
        socket_path: impl Into<PathBuf>,
        state_rx: watch::Receiver<EngineState>,
        desired_tx: watch::Sender<DesiredState>,
        settings: Arc<parking_lot::RwLock<Settings>>,
        log_ring: LogRingBuffer,
    ) -> Self {
        Self {
            socket_path: socket_path.into(),
            state_rx,
            desired_tx,
            settings,
            log_ring,
        }
    }

    pub async fn run(&self) -> std::io::Result<()> {
        if self.socket_path.exists() {
            let _ = std::fs::remove_file(&self.socket_path);
        }

        let name = self.socket_path.clone().to_fs_name::<GenericFilePath>()?;
        let listener = ListenerOptions::new().name(name).create_tokio()?;
        info!("[ipc] listening on {:?}", self.socket_path);

        loop {
            match listener.accept().await {
                Ok(stream) => {
                    let state_rx = self.state_rx.clone();
                    let desired_tx = self.desired_tx.clone();
                    let settings = self.settings.clone();
                    let log_ring = self.log_ring.clone();

                    tokio::spawn(async move {
                        if let Err(e) =
                            handle_client(stream, state_rx, desired_tx, settings, log_ring).await
                        {
                            warn!("[ipc] client disconnected with error: {e}");
                        }
                    });
                }
                Err(e) => {
                    error!("[ipc] accept error: {e}");
                    sleep(Duration::from_millis(50)).await;
                }
            }
        }
    }
}

async fn handle_client(
    stream: Stream,
    state_rx: watch::Receiver<EngineState>,
    desired_tx: watch::Sender<DesiredState>,
    settings: Arc<parking_lot::RwLock<Settings>>,
    log_ring: LogRingBuffer,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let (reader_half, mut writer_half) = stream.split();
    let mut reader = BufReader::new(reader_half);
    let mut line = String::new();

    // 1. Handshake
    let bytes_read = reader.read_line(&mut line).await?;
    if bytes_read == 0 {
        return Ok(());
    }

    let handshake = ClientMessage::from_line(&line)?;
    match handshake {
        ClientMessage::Hello { proto, client } => {
            if proto != PROTOCOL_VERSION {
                let err_msg = ServerMessage::Error {
                    code: ErrorCode::E250,
                    msg: format!(
                        "Protocol version mismatch: client={proto}, server={PROTOCOL_VERSION}"
                    ),
                };
                writer_half.write_all(err_msg.to_line()?.as_bytes()).await?;
                writer_half.flush().await?;
                return Ok(());
            }

            info!("[ipc] handshake successful with client: {client}");
            let reply = ServerMessage::Hello {
                proto: PROTOCOL_VERSION,
                server: env!("CARGO_PKG_VERSION").to_string(),
                caps: vec!["tun".to_string(), "proxy".to_string()],
            };
            writer_half.write_all(reply.to_line()?.as_bytes()).await?;
            writer_half.flush().await?;
        }
        _ => {
            let err_msg = ServerMessage::Error {
                code: ErrorCode::E250,
                msg: "Expected hello handshake".into(),
            };
            writer_half.write_all(err_msg.to_line()?.as_bytes()).await?;
            writer_half.flush().await?;
            return Ok(());
        }
    }

    // 2. Command processing loop with live State & Stats push
    let mut state_watch = state_rx.clone();
    let mut stats_interval = tokio::time::interval(Duration::from_secs(1));
    stats_interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);

    let mut last_rx_bytes = 0u64;
    let mut last_tx_bytes = 0u64;
    let mut last_time = tokio::time::Instant::now();

    line.clear();
    loop {
        tokio::select! {
            read_res = reader.read_line(&mut line) => {
                let bytes = read_res?;
                if bytes == 0 {
                    break;
                }
                let msg = match ClientMessage::from_line(&line) {
                    Ok(m) => m,
                    Err(e) => {
                        let err = ServerMessage::Error {
                            code: ErrorCode::E400,
                            msg: format!("Invalid JSON message: {e}"),
                        };
                        writer_half.write_all(err.to_line()?.as_bytes()).await?;
                        writer_half.flush().await?;
                        line.clear();
                        continue;
                    }
                };

                match msg {
                    ClientMessage::SetDesired { up, epoch } => {
                        let intent = if up {
                            DesiredIntent::Up
                        } else {
                            DesiredIntent::Down
                        };
                        let _ = desired_tx.send(DesiredState { intent, epoch });
                        let resp = ServerMessage::State {
                            state: Box::new(state_watch.borrow().clone()),
                        };
                        writer_half.write_all(resp.to_line()?.as_bytes()).await?;
                    }
                    ClientMessage::GetState => {
                        let resp = ServerMessage::State {
                            state: Box::new(state_watch.borrow().clone()),
                        };
                        writer_half.write_all(resp.to_line()?.as_bytes()).await?;
                    }
                    ClientMessage::GetSettings => {
                        let current_settings = settings.read().clone();
                        let resp = ServerMessage::Settings {
                            settings: Box::new(current_settings),
                        };
                        writer_half.write_all(resp.to_line()?.as_bytes()).await?;
                    }
                    ClientMessage::PatchSettings {
                        settings: new_settings,
                    } => {
                        if let Err(e) = new_settings.validate() {
                            let err = ServerMessage::Error {
                                code: ErrorCode::E400,
                                msg: format!("Invalid settings: {e:?}"),
                            };
                            writer_half.write_all(err.to_line()?.as_bytes()).await?;
                        } else {
                            *settings.write() = *new_settings;
                            let resp = ServerMessage::Pong;
                            writer_half.write_all(resp.to_line()?.as_bytes()).await?;
                        }
                    }
                    ClientMessage::Ping => {
                        let resp = ServerMessage::Pong;
                        writer_half.write_all(resp.to_line()?.as_bytes()).await?;
                    }
                    ClientMessage::Subscribe { stats: _ } => {
                        let resp = ServerMessage::Pong;
                        writer_half.write_all(resp.to_line()?.as_bytes()).await?;
                    }
                    ClientMessage::Unsubscribe => {
                        let resp = ServerMessage::Pong;
                        writer_half.write_all(resp.to_line()?.as_bytes()).await?;
                    }
                    ClientMessage::ProbeNow => {
                        let resp = ServerMessage::Pong;
                        writer_half.write_all(resp.to_line()?.as_bytes()).await?;
                    }
                    ClientMessage::ResetIdentity => {
                        let resp = ServerMessage::Notice {
                            code: ErrorCode::E130,
                            params: HashMap::new(),
                        };
                        writer_half.write_all(resp.to_line()?.as_bytes()).await?;
                    }
                    ClientMessage::ExportDiagnostics => {
                        let st = state_watch.borrow().clone();
                        let sett = settings.read().clone();
                        let diag = log_ring.export_diagnostics(
                            env!("CARGO_PKG_VERSION"),
                            "v2.3.0",
                            &st,
                            &sett,
                            "Endpoints: 0, Rungs: 0",
                        );
                        let resp = ServerMessage::Diagnostics { data: diag };
                        writer_half.write_all(resp.to_line()?.as_bytes()).await?;
                    }
                    ClientMessage::Hello { .. } => {
                        let err = ServerMessage::Error {
                            code: ErrorCode::E400,
                            msg: "Handshake already completed".into(),
                        };
                        writer_half.write_all(err.to_line()?.as_bytes()).await?;
                    }
                }
                writer_half.flush().await?;
                line.clear();
            }

            change_res = state_watch.changed() => {
                if change_res.is_err() {
                    break;
                }
                let st = state_watch.borrow().clone();
                let resp = ServerMessage::State {
                    state: Box::new(st),
                };
                if let Ok(l) = resp.to_line() {
                    let _ = writer_half.write_all(l.as_bytes()).await;
                    let _ = writer_half.flush().await;
                }
            }

            _ = stats_interval.tick() => {
                let st = state_watch.borrow().clone();
                if st.phase == zohal_proto::types::Phase::Connected {
                    let rx_path = "/sys/class/net/zohal0/statistics/rx_bytes";
                    let tx_path = "/sys/class/net/zohal0/statistics/tx_bytes";
                    let cur_rx = std::fs::read_to_string(rx_path)
                        .ok()
                        .and_then(|s| s.trim().parse::<u64>().ok())
                        .unwrap_or(0);
                    let cur_tx = std::fs::read_to_string(tx_path)
                        .ok()
                        .and_then(|s| s.trim().parse::<u64>().ok())
                        .unwrap_or(0);

                    let now = tokio::time::Instant::now();
                    let dt = now.duration_since(last_time).as_secs_f64();
                    let rx_bps = if dt > 0.1 && cur_rx >= last_rx_bytes && last_rx_bytes > 0 {
                        (((cur_rx - last_rx_bytes) as f64 * 8.0) / dt) as u64
                    } else {
                        0
                    };
                    let tx_bps = if dt > 0.1 && cur_tx >= last_tx_bytes && last_tx_bytes > 0 {
                        (((cur_tx - last_tx_bytes) as f64 * 8.0) / dt) as u64
                    } else {
                        0
                    };

                    last_rx_bytes = cur_rx;
                    last_tx_bytes = cur_tx;
                    last_time = now;

                    let stats_msg = ServerMessage::Stats {
                        stats: zohal_proto::types::TrafficStats {
                            rx_total: cur_rx,
                            tx_total: cur_tx,
                            rx_bps,
                            tx_bps,
                        },
                    };
                    if let Ok(l) = stats_msg.to_line() {
                        let _ = writer_half.write_all(l.as_bytes()).await;
                        let _ = writer_half.flush().await;
                    }
                }
            }
        }
    }

    Ok(())
}
