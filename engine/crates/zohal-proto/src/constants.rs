use std::time::Duration;

pub const APP_NAME: &str = "Zohal";
pub const APP_NAME_FA: &str = "زحل";
pub const APP_FULL_NAME: &str = "Zohal Connect | قندشکن زحل";
pub const PROTOCOL_VERSION: u32 = 1;

pub const DEFAULT_TUN_NAME: &str = "zohal0";
pub const WINDOWS_ADAPTER_NAME: &str = "Zohal";
pub const WINDOWS_ADAPTER_GUID: &str = "{6D7A6F68-616C-436F-6E6E-65637454554E}";
pub const FIREWALL_RULE_GROUP: &str = "ZohalDnsGuard";
pub const SERVICE_NAME: &str = "ZohalEngine";

pub const SETTLE_WINDOW: Duration = Duration::from_millis(120);
pub const HEALTH_CHECK_TIMEOUT: Duration = Duration::from_secs(3);
pub const DISCONNECT_TIMEOUT: Duration = Duration::from_millis(300);
pub const DISCONNECT_HARD_TIMEOUT: Duration = Duration::from_secs(3);

pub const UNIX_SOCKET_PATH: &str = "/run/zohal/engine.sock";
pub const WINDOWS_PIPE_NAME: &str = r"\\.\pipe\ZohalEngine";
pub const ANDROID_ABSTRACT_SOCKET: &str = "zohal_engine";

pub const DEFAULT_MTU: u16 = 1280;
pub const MAX_RULES_COUNT: usize = 5000;
pub const MAX_RULE_LENGTH: usize = 255;
pub const RING_BUFFER_CAPACITY: usize = 2000;
