use std::{env, fs, path::PathBuf};

pub(crate) fn directory() -> PathBuf {
    env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .filter(|p| p.is_absolute())
        .unwrap_or_else(|| PathBuf::from(env::var_os("HOME").unwrap_or_default()).join(".config"))
        .join("streambot")
}

#[derive(Clone)]
pub(crate) struct Settings {
    pub(crate) host: String,
    pub(crate) ws_port: u16,
    pub(crate) rest_port: u16,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            host: "127.0.0.1".into(),
            ws_port: 8100,
            rest_port: 8105,
        }
    }
}

impl Settings {
    pub(crate) fn load() -> Self {
        let mut config = Self::default();
        let path = env::args()
            .skip(1)
            .collect::<Vec<_>>()
            .windows(2)
            .find(|args| args[0] == "--app-config" || args[0] == "--config_path")
            .map(|args| PathBuf::from(&args[1]))
            .or_else(|| env::var_os("STREAMBOT_TOUCH_CONFIG").map(PathBuf::from))
            .unwrap_or_else(|| directory().join("streambot-touch.cfg"));
        if let Ok(contents) = fs::read_to_string(&path) {
            let mut section = String::new();
            for line in contents.lines().map(str::trim) {
                if line.starts_with('#') || line.starts_with(';') || line.is_empty() {
                    continue;
                }
                if line.starts_with('[') && line.ends_with(']') {
                    section = line[1..line.len() - 1].trim().to_ascii_lowercase();
                    continue;
                }
                if section != "connection" {
                    continue;
                }
                if let Some((key, value)) = line.split_once(':') {
                    let value = value.trim();
                    match key.trim().to_ascii_lowercase().as_str() {
                        "host" if !value.is_empty() => config.host = value.into(),
                        "websocketport" => {
                            if let Some(port) = value.parse().ok().filter(|p| *p > 0) {
                                config.ws_port = port;
                            }
                        }
                        "restport" => {
                            if let Some(port) = value.parse().ok().filter(|p| *p > 0) {
                                config.rest_port = port;
                            }
                        }
                        _ => {}
                    }
                }
            }
        }
        config
    }
    pub(crate) fn http_url(&self) -> String {
        format!("http://{}:{}/api/status", self.host, self.rest_port)
    }
    pub(crate) fn ws_url(&self) -> String {
        format!("ws://{}:{}", self.host, self.ws_port)
    }
}

pub(crate) mod dashboard;
