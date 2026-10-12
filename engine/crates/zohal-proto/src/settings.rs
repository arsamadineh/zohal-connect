use crate::constants::{MAX_RULES_COUNT, MAX_RULE_LENGTH};
use crate::types::{ConnectionMode, IpVersion, NoizeProfile, ScanProfile, Scope};
use serde::{Deserialize, Serialize};
use std::net::IpAddr;
use std::str::FromStr;

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")]
pub enum RuleKind {
    #[serde(alias = "domain")]
    Domain,
    #[serde(alias = "full")]
    Full,
    #[serde(alias = "keyword")]
    Keyword,
    #[serde(alias = "regexp")]
    Regexp,
    #[serde(alias = "cidr")]
    Cidr,
    #[serde(alias = "port")]
    Port,
    #[serde(alias = "private")]
    Private,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Rule {
    pub kind: RuleKind,
    pub value: String,
}

impl Rule {
    pub fn new(kind: RuleKind, value: impl Into<String>) -> Result<Self, String> {
        let val = value.into();
        Self::validate_entry(&kind, &val)?;
        Ok(Self { kind, value: val })
    }

    pub fn validate_entry(kind: &RuleKind, val: &str) -> Result<(), String> {
        if val.is_empty() && *kind != RuleKind::Private {
            return Err("قاعده نمیتواند خالی باشد.".to_string());
        }
        if val.len() > MAX_RULE_LENGTH {
            return Err(format!(
                "طول قاعده نمیتواند بیشتر از {} نویسه باشد.",
                MAX_RULE_LENGTH
            ));
        }

        match kind {
            RuleKind::Private => {
                if !val.is_empty() && val != "private" {
                    return Err("قاعده خصوصی فقط مقدار private را میپذیرد.".to_string());
                }
            }
            RuleKind::Domain => {
                if val.contains('/') || val.contains(':') || val.contains(' ') {
                    return Err("نام دامنه نامعتبر است.".to_string());
                }
            }
            RuleKind::Full => {
                let stripped = val.strip_prefix("full:").unwrap_or(val);
                if stripped.is_empty() || stripped.contains('/') || stripped.contains(':') {
                    return Err("دامنه دقیق نامعتبر است.".to_string());
                }
            }
            RuleKind::Keyword => {
                let stripped = val.strip_prefix("keyword:").unwrap_or(val);
                if stripped.is_empty() {
                    return Err("کلمه کلیدی نمیتواند خالی باشد.".to_string());
                }
            }
            RuleKind::Regexp => {
                let stripped = val.strip_prefix("regexp:").unwrap_or(val);
                if stripped.is_empty() {
                    return Err("عبارت باقاعده نمیتواند خالی باشد.".to_string());
                }
            }
            RuleKind::Cidr => {
                if val.parse::<IpAddr>().is_err() {
                    // Check if it's a CIDR
                    let parts: Vec<&str> = val.split('/').collect();
                    if parts.len() != 2
                        || parts[0].parse::<IpAddr>().is_err()
                        || parts[1].parse::<u8>().is_err()
                    {
                        return Err("نشانی IP یا زیرشبکه CIDR نامعتبر است.".to_string());
                    }
                }
            }
            RuleKind::Port => {
                let stripped = val.strip_prefix("port:").unwrap_or(val);
                if let Some((start, end)) = stripped.split_once('-') {
                    let s = start
                        .parse::<u16>()
                        .map_err(|_| "شماره پورت نامعتبر است.".to_string())?;
                    let e = end
                        .parse::<u16>()
                        .map_err(|_| "شماره پورت نامعتبر است.".to_string())?;
                    if s > e {
                        return Err("بازه پورت نامعتبر است.".to_string());
                    }
                } else {
                    stripped
                        .parse::<u16>()
                        .map_err(|_| "شماره پورت نامعتبر است.".to_string())?;
                }
            }
        }
        Ok(())
    }

    pub fn to_aether_line(&self) -> String {
        match self.kind {
            RuleKind::Private => "private".to_string(),
            RuleKind::Domain => self.value.clone(),
            RuleKind::Full => {
                if self.value.starts_with("full:") {
                    self.value.clone()
                } else {
                    format!("full:{}", self.value)
                }
            }
            RuleKind::Keyword => {
                if self.value.starts_with("keyword:") {
                    self.value.clone()
                } else {
                    format!("keyword:{}", self.value)
                }
            }
            RuleKind::Regexp => {
                if self.value.starts_with("regexp:") {
                    self.value.clone()
                } else {
                    format!("regexp:{}", self.value)
                }
            }
            RuleKind::Cidr => self.value.clone(),
            RuleKind::Port => {
                if self.value.starts_with("port:") {
                    self.value.clone()
                } else {
                    format!("port:{}", self.value)
                }
            }
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")]
pub enum AppSplitMode {
    #[serde(alias = "all")]
    All,
    #[serde(alias = "only")]
    Only,
    #[serde(alias = "except")]
    Except,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AppSplit {
    pub mode: AppSplitMode,
    pub packages: Vec<String>,
}

impl Default for AppSplit {
    fn default() -> Self {
        Self {
            mode: AppSplitMode::All,
            packages: Vec::new(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RoutingSettings {
    pub smart_domestic_direct: bool,
    pub lan_direct: bool,
    pub direct_rules: Vec<Rule>,
    pub block_rules: Vec<Rule>,
    pub app_split: AppSplit,
}

impl Default for RoutingSettings {
    fn default() -> Self {
        Self {
            smart_domestic_direct: true,
            lan_direct: true,
            direct_rules: Vec::new(),
            block_rules: Vec::new(),
            app_split: AppSplit::default(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DnsSettings {
    pub servers: Vec<String>,
}

impl Default for DnsSettings {
    fn default() -> Self {
        Self {
            servers: vec![
                "1.1.1.1".to_string(),
                "1.0.0.1".to_string(),
                "2606:4700:4700::1111".to_string(),
                "2606:4700:4700::1001".to_string(),
            ],
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct AdvancedSettings {
    pub fragment: bool,
    pub ech: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Settings {
    pub connection_mode: ConnectionMode,
    pub ip_version: IpVersion,
    pub scan_profile: ScanProfile,
    pub noize_profile: NoizeProfile,
    pub scope: Scope,
    pub kill_switch: bool,
    pub auto_connect_on_launch: bool,
    pub restore_last_state: bool,
    pub auto_connect_on_boot: bool,
    pub start_with_system: bool,
    pub minimize_to_tray: bool,
    pub routing: RoutingSettings,
    pub dns: DnsSettings,
    pub advanced: AdvancedSettings,
    pub diagnostic_log: bool,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            connection_mode: ConnectionMode::Auto,
            ip_version: IpVersion::Auto,
            scan_profile: ScanProfile::Turbo,
            noize_profile: NoizeProfile::Auto,
            scope: Scope::Tun,
            kill_switch: true,
            auto_connect_on_launch: true,
            restore_last_state: true,
            auto_connect_on_boot: false,
            start_with_system: false,
            minimize_to_tray: true,
            routing: RoutingSettings::default(),
            dns: DnsSettings::default(),
            advanced: AdvancedSettings::default(),
            diagnostic_log: true,
        }
    }
}

impl Settings {
    pub fn validate(&self) -> Result<(), String> {
        if self.dns.servers.is_empty() {
            return Err("حداقل یک سرور DNS باید مشخص شود.".to_string());
        }
        for s in &self.dns.servers {
            if IpAddr::from_str(s).is_err() {
                return Err(format!("نشانی سرور دیاناس نامعتبر است: {s}"));
            }
        }
        if self.routing.direct_rules.len() + self.routing.block_rules.len() > MAX_RULES_COUNT {
            return Err(format!(
                "تعداد کل قواعد نمیتواند بیش از {} باشد.",
                MAX_RULES_COUNT
            ));
        }
        for r in &self.routing.direct_rules {
            Rule::validate_entry(&r.kind, &r.value)?;
        }
        for r in &self.routing.block_rules {
            Rule::validate_entry(&r.kind, &r.value)?;
        }
        Ok(())
    }
}
