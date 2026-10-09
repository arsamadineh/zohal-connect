pub trait TunFrontend: Send + Sync {
    fn start(&mut self, proxy_url: &str) -> Result<(), String>;
    fn stop(&mut self) -> Result<(), String>;
}
