use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::{env, fs, path::PathBuf};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct StreambotSettings {
    pub language: String,
}

fn settings_path() -> Result<PathBuf, String> {
    let home = env::var("HOME").map_err(|_| "HOME not found".to_string())?;
    Ok(PathBuf::from(home).join(".config/streambot/streambot-settings.json"))
}

fn system_language() -> String {
    env::var("LC_ALL")
        .or_else(|_| env::var("LC_MESSAGES"))
        .or_else(|_| env::var("LANG"))
        .or_else(|_| env::var("LANGUAGE"))
        .unwrap_or_else(|_| "en".to_string())
        .split('.')
        .next()
        .unwrap_or("en")
        .split('_')
        .next()
        .unwrap_or("en")
        .split(':')
        .next()
        .unwrap_or("en")
        .to_lowercase()
}

fn read_settings_json() -> Result<Value, String> {
    let path = settings_path()?;

    if !path.exists() {
        return Ok(json!({
            "language": system_language()
        }));
    }

    let raw = fs::read_to_string(&path).map_err(|e| e.to_string())?;

    match serde_json::from_str::<Value>(&raw) {
        Ok(Value::Object(settings)) => Ok(Value::Object(settings)),
        _ => Ok(json!({
            "language": system_language()
        })),
    }
}

fn write_settings_json(settings: &Value) -> Result<(), String> {
    let path = settings_path()?;

    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    }

    let json = serde_json::to_string_pretty(settings).map_err(|e| e.to_string())?;
    fs::write(path, format!("{}\n", json)).map_err(|e| e.to_string())
}

fn settings_response(settings: &Value) -> StreambotSettings {
    let language = settings
        .get("language")
        .and_then(Value::as_str)
        .map(|value| value.trim().to_lowercase())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(system_language);

    StreambotSettings { language }
}

#[tauri::command]
pub fn get_streambot_settings() -> Result<StreambotSettings, String> {
    let mut settings = read_settings_json()?;

    let language = settings_response(&settings).language;

    let changed = settings
        .get("language")
        .and_then(Value::as_str)
        != Some(language.as_str());

    if changed {
        settings["language"] = json!(language.clone());
        write_settings_json(&settings)?;
    }

    Ok(StreambotSettings { language })
}

#[tauri::command]
pub fn set_streambot_language(language: String) -> Result<StreambotSettings, String> {
    let language = language.trim().to_lowercase();

    if language.is_empty() {
        return Err("language is required".to_string());
    }

    let mut settings = read_settings_json()?;

    let changed = settings
        .get("language")
        .and_then(Value::as_str)
        != Some(language.as_str());

    if changed {
        settings["language"] = json!(language.clone());
        write_settings_json(&settings)?;
    }

    Ok(StreambotSettings { language })
}