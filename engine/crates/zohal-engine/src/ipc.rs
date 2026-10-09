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

    // 2. Command processing loop
    line.clear();
    while reader.read_line(&mut line).await? > 0 {
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
                    state: Box::new(state_rx.borrow().clone()),
                };
                writer_half.write_all(resp.to_line()?.as_bytes()).await?;
            }
            ClientMessage::GetState => {
                let resp = ServerMessage::State {
                    state: Box::new(state_rx.borrow().clone()),
                };
                writer_half.write_all(resp.to_line()?.as_bytes()).await?;
            }
            ClientMessage::GetSettings => {
                let _current = settings.read().clone();
                let resp = ServerMessage::Notice {
                    code: ErrorCode::E100, // Reuse notice or settings encoding
                    params: HashMap::new(),
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
            ClientMessage::ExportDiagnostics => {
                let st = state_rx.borrow().clone();
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
            _ => {
                let resp = ServerMessage::Pong;
                writer_half.write_all(resp.to_line()?.as_bytes()).await?;
            }
        }
        writer_half.flush().await?;
        line.clear();
    }

    Ok(())
}
