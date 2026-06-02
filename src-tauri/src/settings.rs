use serde::{Deserialize, Serialize};
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

fn write_settings_file(settings: &StreambotSettings) -> Result<(), String> {
    let path = settings_path()?;

    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    }

    let json = serde_json::to_string_pretty(settings).map_err(|e| e.to_string())?;
    fs::write(path, json).map_err(|e| e.to_string())
}

#[tauri::command]
pub fn get_streambot_settings() -> Result<StreambotSettings, String> {
    let path = settings_path()?;

    if !path.exists() {
        let settings = StreambotSettings {
            language: system_language(),
        };

        write_settings_file(&settings)?;
        return Ok(settings);
    }

    let raw = fs::read_to_string(&path).map_err(|e| e.to_string())?;

    match serde_json::from_str::<StreambotSettings>(&raw) {
        Ok(settings) => Ok(settings),
        Err(_) => {
            let settings = StreambotSettings {
                language: system_language(),
            };

            write_settings_file(&settings)?;
            Ok(settings)
        }
    }
}

#[tauri::command]
pub fn set_streambot_language(language: String) -> Result<StreambotSettings, String> {
    let language = language.trim().to_lowercase();

    if language.is_empty() {
        return Err("language is required".to_string());
    }

    let settings = StreambotSettings { language };

    write_settings_file(&settings)?;

    Ok(settings)
}