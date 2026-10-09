use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use tokio_util::sync::CancellationToken;
use tracing::{error, info};
use tun2proxy::ProxyParameters;
use tun2proxy::{general_run_async, ArgDns, Args};
use zohal_proto::types::TrafficStats;

pub trait TunFrontend: Send + Sync {
    fn start(&mut self, tun_name: &str, proxy_port: u16, mtu: u16) -> Result<(), String>;
    fn stop(&mut self) -> Result<(), String>;
    fn get_stats(&self) -> TrafficStats;
}

pub struct Tun2ProxyFrontend {
    cancel_token: Option<CancellationToken>,
    rx_total: Arc<AtomicU64>,
    tx_total: Arc<AtomicU64>,
    last_rx: u64,
    last_tx: u64,
    last_stat_time: std::time::Instant,
}

impl Default for Tun2ProxyFrontend {
    fn default() -> Self {
        Self::new()
    }
}

impl Tun2ProxyFrontend {
    pub fn new() -> Self {
        Self {
            cancel_token: None,
            rx_total: Arc::new(AtomicU64::new(0)),
            tx_total: Arc::new(AtomicU64::new(0)),
            last_rx: 0,
            last_tx: 0,
            last_stat_time: std::time::Instant::now(),
        }
    }
}

impl TunFrontend for Tun2ProxyFrontend {
    fn start(&mut self, tun_name: &str, proxy_port: u16, mtu: u16) -> Result<(), String> {
        let proxy_url = format!("socks5://127.0.0.1:{}", proxy_port);
        let proxy_params = ProxyParameters::try_from(proxy_url.as_str())
            .map_err(|e| format!("Invalid proxy URL: {e}"))?;

        let args = Args {
            proxy: proxy_params,
            tun: Some(tun_name.to_string()),
            ipv6_enabled: true,
            dns: ArgDns::Direct,
            setup: false, // Zohal manages its own policy routing with journaling
            ..Default::default()
        };

        let token = CancellationToken::new();
        self.cancel_token = Some(token.clone());
        let tun_name_owned = tun_name.to_string();

        tokio::spawn(async move {
            info!("[tun2proxy] starting on {tun_name_owned} MTU {mtu}");
            if let Err(e) = general_run_async(args, mtu, false, token).await {
                error!("[tun2proxy] runner exited with error: {e}");
            } else {
                info!("[tun2proxy] runner stopped cleanly");
            }
        });

        Ok(())
    }

    fn stop(&mut self) -> Result<(), String> {
        if let Some(token) = self.cancel_token.take() {
            token.cancel();
            info!("[tun2proxy] cancellation token triggered");
        }
        Ok(())
    }

    fn get_stats(&self) -> TrafficStats {
        let rx = self.rx_total.load(Ordering::Relaxed);
        let tx = self.tx_total.load(Ordering::Relaxed);
        let now = std::time::Instant::now();
        let elapsed = now.duration_since(self.last_stat_time).as_secs_f64();

        let (rx_bps, tx_bps) = if elapsed > 0.1 {
            let rx_diff = rx.saturating_sub(self.last_rx);
            let tx_diff = tx.saturating_sub(self.last_tx);
            (
                (rx_diff as f64 * 8.0 / elapsed) as u64,
                (tx_diff as f64 * 8.0 / elapsed) as u64,
            )
        } else {
            (0, 0)
        };

        TrafficStats {
            rx_bps,
            tx_bps,
            rx_total: rx,
            tx_total: tx,
        }
    }
}
