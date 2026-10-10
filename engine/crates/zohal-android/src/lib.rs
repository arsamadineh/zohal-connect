// zohal-android: Android JNI entry points for the TUN data path.
//
// The Kotlin `ZohalVpnService` hands the file descriptor from
// `VpnService.Builder.establish()` to `TunBridge.startTun(fd, socksPort)`.
// This runs tun2proxy in-process with `tun_fd` (the same runner the desktop
// engine uses, see `zohal-tun`), forwarding TUN packets through the local
// Aether SOCKS5 listener. No new dependencies: JNI types are declared
// manually (`jint` is `i32`, object references are opaque pointers) because
// these two functions never touch the `JNIEnv`.

use std::os::raw::{c_int, c_void};
use std::sync::Mutex;
use tokio_util::sync::CancellationToken;
use tracing::{error, info};
use tun2proxy::{general_run_async, ArgDns, Args, ProxyParameters};

static TUN_TOKEN: Mutex<Option<CancellationToken>> = Mutex::new(None);

/// Starts the tun2proxy packet forwarder on an Android TUN file descriptor.
///
/// # Safety
/// Called by the JVM only, through `TunBridge.startTun`. `fd` must be a valid
/// open TUN file descriptor owned by `ZohalVpnService`, and the two pointer
/// arguments must be the JNI values the JVM passes (they are ignored).
#[allow(non_snake_case)]
#[no_mangle]
pub unsafe extern "system" fn Java_app_zohal_connect_TunBridge_startTun(
    _env: *mut c_void,
    _cls: *mut c_void,
    fd: c_int,
    socks_port: c_int,
    mtu: c_int,
) -> c_int {
    stop_runner();

    let proxy_url = format!("socks5://127.0.0.1:{socks_port}");
    let proxy_params = match ProxyParameters::try_from(proxy_url.as_str()) {
        Ok(p) => p,
        Err(e) => {
            error!("[zohal-android] invalid proxy url: {e}");
            return 1;
        }
    };

    let args = Args {
        proxy: proxy_params,
        tun_fd: Some(fd),
        close_fd_on_drop: Some(false),
        ipv6_enabled: true,
        dns: ArgDns::Direct,
        setup: false,
        ..Default::default()
    };

    let mtu_u16: u16 = if mtu > 0 && mtu <= 65535 {
        mtu as u16
    } else {
        1280
    };

    let token = CancellationToken::new();
    *TUN_TOKEN.lock().unwrap_or_else(|e| e.into_inner()) = Some(token.clone());

    std::thread::spawn(move || {
        let rt = match tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
        {
            Ok(rt) => rt,
            Err(e) => {
                error!("[zohal-android] tokio runtime failed: {e}");
                return;
            }
        };
        info!("[zohal-android] tun runner starting on fd={fd} mtu={mtu_u16}");
        rt.block_on(async move {
            if let Err(e) = general_run_async(args, mtu_u16, false, token).await {
                error!("[zohal-android] tun runner exited: {e}");
            } else {
                info!("[zohal-android] tun runner stopped cleanly");
            }
        });
    });

    0
}

/// Stops the tun2proxy packet forwarder started by `startTun`.
///
/// # Safety
/// Called by the JVM only, through `TunBridge.stopTun`. The pointer arguments
/// must be the JNI values the JVM passes (they are ignored).
#[allow(non_snake_case)]
#[no_mangle]
pub unsafe extern "system" fn Java_app_zohal_connect_TunBridge_stopTun(
    _env: *mut c_void,
    _cls: *mut c_void,
) {
    stop_runner();
}

fn stop_runner() {
    if let Ok(mut guard) = TUN_TOKEN.lock() {
        if let Some(token) = guard.take() {
            token.cancel();
            info!("[zohal-android] tun runner cancellation requested");
        }
    }
}
