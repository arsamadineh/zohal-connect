#![cfg_attr(not(test), deny(clippy::unwrap_used, clippy::expect_used))]

pub mod constants;
pub mod error;
pub mod ipc;
pub mod settings;
pub mod types;

pub use constants::*;
pub use error::ErrorCode;
pub use ipc::{ClientMessage, ServerMessage};
pub use settings::{
    AppSplit, AppSplitMode, DnsSettings, RoutingSettings, Rule, RuleKind, Settings,
};
pub use types::{
    ConnectionMode, DesiredIntent, DesiredState, EngineState, IpVersion, NoizeProfile, Phase,
    ScanProfile, Scope, Stage, TrafficStats, Transport,
};

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    #[test]
    fn test_default_settings_valid() {
        let s = Settings::default();
        assert!(s.validate().is_ok());
    }

    #[test]
    fn test_rule_validation() {
        assert!(Rule::new(RuleKind::Domain, "example.com").is_ok());
        assert!(Rule::new(RuleKind::Cidr, "10.0.0.0/8").is_ok());
        assert!(Rule::new(RuleKind::Cidr, "1.1.1.1").is_ok());
        assert!(Rule::new(RuleKind::Port, "8080").is_ok());
        assert!(Rule::new(RuleKind::Port, "8000-8080").is_ok());
        assert!(Rule::new(RuleKind::Private, "private").is_ok());

        assert!(Rule::new(RuleKind::Port, "9000-8000").is_err());
        assert!(Rule::new(RuleKind::Domain, "invalid domain with spaces").is_err());
    }

    #[test]
    fn test_ipc_roundtrip() {
        let msg = ClientMessage::SetDesired {
            up: true,
            epoch: 42,
        };
        let line = msg.to_line().unwrap();
        let parsed = ClientMessage::from_line(&line).unwrap();
        assert_eq!(msg, parsed);

        let srv = ServerMessage::Hello {
            proto: 1,
            server: "0.1.0".to_string(),
            caps: vec!["tun".to_string()],
        };
        let srv_line = srv.to_line().unwrap();
        let srv_parsed = ServerMessage::from_line(&srv_line).unwrap();
        assert_eq!(srv, srv_parsed);
    }

    proptest! {
        // T1.11: IPC parser fuzz test ensuring no input panics the parser
        #[test]
        fn fuzz_client_message_parser(s in "\\PC*") {
            let _ = ClientMessage::from_line(&s);
        }

        #[test]
        fn fuzz_server_message_parser(s in "\\PC*") {
            let _ = ServerMessage::from_line(&s);
        }
    }
}
