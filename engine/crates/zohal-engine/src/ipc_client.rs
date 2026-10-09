use interprocess::local_socket::tokio::prelude::*;
use interprocess::local_socket::tokio::{RecvHalf, SendHalf, Stream};
use interprocess::local_socket::{GenericFilePath, ToFsName};
use std::path::Path;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use zohal_proto::constants::PROTOCOL_VERSION;
use zohal_proto::ipc::{ClientMessage, ServerMessage};
use zohal_proto::types::EngineState;

pub struct IpcClient {
    reader: BufReader<RecvHalf>,
    writer: SendHalf,
}

impl IpcClient {
    pub async fn connect(
        socket_path: &Path,
    ) -> Result<Self, Box<dyn std::error::Error + Send + Sync>> {
        let name = socket_path.to_fs_name::<GenericFilePath>()?;
        let stream = Stream::connect(name).await?;
        let (reader_half, mut writer) = stream.split();
        let mut reader = BufReader::new(reader_half);

        // Handshake
        let hello = ClientMessage::Hello {
            proto: PROTOCOL_VERSION,
            client: "zohal-client".to_string(),
        };
        writer.write_all(hello.to_line()?.as_bytes()).await?;
        writer.flush().await?;

        let mut line = String::new();
        reader.read_line(&mut line).await?;
        let resp = ServerMessage::from_line(&line)?;

        match resp {
            ServerMessage::Hello { proto, .. } => {
                if proto != PROTOCOL_VERSION {
                    return Err(format!("Server returned mismatched protocol: {proto}").into());
                }
            }
            ServerMessage::Error { code, msg } => {
                return Err(format!("Handshake failed with {:?}: {msg}", code).into());
            }
            _ => {
                return Err("Unexpected server handshake response".into());
            }
        }

        Ok(Self { reader, writer })
    }

    pub async fn send_cmd(
        &mut self,
        cmd: &ClientMessage,
    ) -> Result<ServerMessage, Box<dyn std::error::Error + Send + Sync>> {
        let line = cmd.to_line()?;
        self.writer.write_all(line.as_bytes()).await?;
        self.writer.flush().await?;

        let mut resp_line = String::new();
        self.reader.read_line(&mut resp_line).await?;
        let resp = ServerMessage::from_line(&resp_line)?;
        Ok(resp)
    }

    pub async fn set_desired(
        &mut self,
        up: bool,
        epoch: u64,
    ) -> Result<EngineState, Box<dyn std::error::Error + Send + Sync>> {
        let cmd = ClientMessage::SetDesired { up, epoch };
        match self.send_cmd(&cmd).await? {
            ServerMessage::State { state } => Ok(*state),
            ServerMessage::Error { code, msg } => {
                Err(format!("SetDesired error {:?}: {}", code, msg).into())
            }
            _ => Err("Unexpected response to SetDesired".into()),
        }
    }

    pub async fn get_state(
        &mut self,
    ) -> Result<EngineState, Box<dyn std::error::Error + Send + Sync>> {
        let cmd = ClientMessage::GetState;
        match self.send_cmd(&cmd).await? {
            ServerMessage::State { state } => Ok(*state),
            ServerMessage::Error { code, msg } => {
                Err(format!("GetState error {:?}: {}", code, msg).into())
            }
            _ => Err("Unexpected response to GetState".into()),
        }
    }

    pub async fn ping(&mut self) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let cmd = ClientMessage::Ping;
        match self.send_cmd(&cmd).await? {
            ServerMessage::Pong => Ok(()),
            ServerMessage::Error { code, msg } => {
                Err(format!("Ping error {:?}: {}", code, msg).into())
            }
            _ => Err("Unexpected response to Ping".into()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ipc::IpcServer;
    use crate::log_ring::LogRingBuffer;
    use std::sync::Arc;
    use tempfile::tempdir;
    use tokio::sync::watch;
    use zohal_proto::settings::Settings;
    use zohal_proto::types::{DesiredIntent, DesiredState, EngineState, Phase};

    #[tokio::test]
    async fn test_ipc_server_client_roundtrip() {
        let dir = tempdir().unwrap();
        let sock_path = dir.path().join("test_engine.sock");

        let (_state_tx, state_rx) = watch::channel(EngineState::default());
        let (desired_tx, desired_rx) = watch::channel(DesiredState::default());
        let settings = Arc::new(parking_lot::RwLock::new(Settings::default()));
        let log_ring = LogRingBuffer::new();

        let server = IpcServer::new(sock_path.clone(), state_rx, desired_tx, settings, log_ring);

        tokio::spawn(async move {
            let _ = server.run().await;
        });

        // Wait a bit for server to start listening
        tokio::time::sleep(std::time::Duration::from_millis(50)).await;

        let mut client = IpcClient::connect(&sock_path)
            .await
            .expect("Failed to connect IPC client");
        client.ping().await.expect("Ping failed");

        let state = client.get_state().await.expect("GetState failed");
        assert_eq!(state.phase, Phase::Idle);

        client
            .set_desired(true, 1)
            .await
            .expect("SetDesired failed");
        assert_eq!(desired_rx.borrow().intent, DesiredIntent::Up);
        assert_eq!(desired_rx.borrow().epoch, 1);
    }
}
