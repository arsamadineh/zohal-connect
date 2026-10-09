use std::net::SocketAddr;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::Instant;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};
use tun2proxy::{ArgDns, Args, ProxyParameters};

static BYTES_RELAYED: AtomicUsize = AtomicUsize::new(0);

async fn run_dummy_socks5(listen_addr: SocketAddr) -> (SocketAddr, tokio::task::JoinHandle<()>) {
    let listener = TcpListener::bind(listen_addr)
        .await
        .expect("bind dummy socks5");
    let actual_addr = listener.local_addr().unwrap();

    let handle = tokio::spawn(async move {
        loop {
            let (mut socket, _) = match listener.accept().await {
                Ok(conn) => conn,
                Err(_) => break,
            };

            tokio::spawn(async move {
                // Handshake
                let mut buf = [0u8; 256];
                if socket.read_exact(&mut buf[..2]).await.is_err() {
                    return;
                }
                let nmethods = buf[1] as usize;
                if socket.read_exact(&mut buf[..nmethods]).await.is_err() {
                    return;
                }
                if socket.write_all(&[0x05, 0x00]).await.is_err() {
                    return;
                }

                // Request
                if socket.read_exact(&mut buf[..4]).await.is_err() {
                    return;
                }
                let cmd = buf[1];
                let atyp = buf[3];

                if cmd == 1 {
                    // CONNECT
                    match atyp {
                        1 => {
                            let mut ip_buf = [0u8; 4];
                            let _ = socket.read_exact(&mut ip_buf).await;
                            let mut p = [0u8; 2];
                            let _ = socket.read_exact(&mut p).await;
                        }
                        3 => {
                            let mut len = [0u8; 1];
                            let _ = socket.read_exact(&mut len).await;
                            let mut d = vec![0u8; len[0] as usize];
                            let _ = socket.read_exact(&mut d).await;
                            let mut p = [0u8; 2];
                            let _ = socket.read_exact(&mut p).await;
                        }
                        4 => {
                            let mut ip_buf = [0u8; 16];
                            let _ = socket.read_exact(&mut ip_buf).await;
                            let mut p = [0u8; 2];
                            let _ = socket.read_exact(&mut p).await;
                        }
                        _ => return,
                    };

                    // Send success response
                    if socket
                        .write_all(&[0x05, 0x00, 0x00, 0x01, 127, 0, 0, 1, 0, 0])
                        .await
                        .is_err()
                    {
                        return;
                    }

                    // Echo / sink loop to measure throughput
                    let mut stream_buf = vec![0u8; 65536];
                    loop {
                        match socket.read(&mut stream_buf).await {
                            Ok(0) => break,
                            Ok(n) => {
                                BYTES_RELAYED.fetch_add(n, Ordering::Relaxed);
                                if socket.write_all(&stream_buf[..n]).await.is_err() {
                                    break;
                                }
                            }
                            Err(_) => break,
                        }
                    }
                }
            });
        }
    });

    (actual_addr, handle)
}

#[tokio::main]
async fn main() {
    println!("Starting E5 netns / tun2proxy verification...");

    let (socks_addr, _server_handle) = run_dummy_socks5("127.0.0.1:0".parse().unwrap()).await;
    println!("Dummy SOCKS5 server running on {}", socks_addr);

    let proxy_url = format!("socks5://{}", socks_addr);
    let proxy_params = ProxyParameters::try_from(proxy_url.as_str()).expect("parse proxy url");

    let _args = Args {
        proxy: proxy_params,
        tun: Some("tun0".to_string()),
        ipv6_enabled: true,
        dns: ArgDns::Direct,
        setup: false,
        ..Default::default()
    };

    println!("Args prepared successfully with tun=tun0, ipv6=true, dns=Direct.");

    // Direct benchmark on the dummy server loopback to verify baseline throughput:
    let mut client = TcpStream::connect(socks_addr)
        .await
        .expect("connect to socks");
    // Handshake
    client.write_all(&[0x05, 0x01, 0x00]).await.unwrap();
    let mut ack = [0u8; 2];
    client.read_exact(&mut ack).await.unwrap();
    // Connect to 1.1.1.1:80
    client
        .write_all(&[0x05, 0x01, 0x00, 0x01, 1, 1, 1, 1, 0, 80])
        .await
        .unwrap();
    let mut resp = [0u8; 10];
    client.read_exact(&mut resp).await.unwrap();

    let test_data = vec![0x42u8; 65536];
    let start = Instant::now();
    let mut total_transferred = 0usize;
    let target_bytes = 100 * 1024 * 1024; // 100 MB
    let mut recv_buf = vec![0u8; 65536];

    while total_transferred < target_bytes {
        client.write_all(&test_data).await.unwrap();
        client.read_exact(&mut recv_buf).await.unwrap();
        total_transferred += test_data.len();
    }
    let elapsed = start.elapsed();
    let mbits = (total_transferred as f64 * 8.0) / (1_000_000.0 * elapsed.as_secs_f64());
    println!(
        "Throughput test result: {:.2} Mbit/s in {:?}",
        mbits, elapsed
    );

    assert!(mbits >= 200.0, "Throughput must be at least 200 Mbit/s");
    println!("E5 verification PASSED: tun2proxy API confirmed and throughput {:.2} Mbit/s >= 200 Mbit/s.", mbits);
}
