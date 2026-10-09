use zohal_proto::types::Scope;

pub trait Platform: Send + Sync {
    fn setup_tun(&self, scope: Scope) -> Result<(), String>;
    fn teardown_tun(&self) -> Result<(), String>;
}
