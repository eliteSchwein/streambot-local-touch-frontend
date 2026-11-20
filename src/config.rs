use serde_json::{json, Value};
use std::{
    env, fs, io,
    path::{Path, PathBuf},
};

pub(crate) fn directory() -> PathBuf {
    env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .filter(|p| p.is_absolute())
        .unwrap_or_else(|| PathBuf::from(env::var_os("HOME").unwrap_or_default()).join(".config"))
        .join("streambot")
}

pub(crate) fn settings_path() -> PathBuf {
    directory().join("streambot-settings.json")
}

pub(crate) fn touch_dev_page(path: &Path) -> bool {
    read_settings(path)
        .ok()
        .and_then(|settings| settings["touch_dev_page"].as_bool())
        .unwrap_or(false)
}

pub(crate) fn save_touch_dev_page(path: &Path, enabled: bool) -> io::Result<()> {
    let mut settings = read_settings(path)?;
    settings["touch_dev_page"] = json!(enabled);
    write_settings(path, &settings)
}

fn read_settings(path: &Path) -> io::Result<Value> {
    let data = match fs::read_to_string(path) {
        Ok(contents) => serde_json::from_str::<Value>(&contents).map_err(|e| {
            io::Error::new(
                io::ErrorKind::InvalidData,
                format!("Invalid settings JSON: {e}"),
            )
        })?,
        Err(e) if e.kind() == io::ErrorKind::NotFound => json!({}),
        Err(e) => return Err(e),
    };
    if !data.is_object() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            "Invalid settings root",
        ));
    }
    Ok(data)
}

fn write_settings(path: &Path, data: &Value) -> io::Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let temp = path.with_extension("json.tmp");
    fs::write(
        &temp,
        format!(
            "{}\n",
            serde_json::to_string_pretty(data).map_err(io::Error::other)?
        ),
    )?;
    fs::rename(temp, path)
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
