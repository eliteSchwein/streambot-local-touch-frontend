//! Local dashboard configuration compatible with Quickshell Config.qml.
use serde_json::{json, Value};
use std::{fs, io, path::PathBuf};

fn path() -> PathBuf {
    super::directory().join("streambot-settings.json")
}

pub(crate) fn load() -> [String; 4] {
    let default = || {
        [
            "interactions".into(),
            "auto_macros".into(),
            "music".into(),
            "".into(),
        ]
    };
    let Ok(text) = fs::read_to_string(path()) else {
        return default();
    };
    let Ok(data) = serde_json::from_str::<Value>(&text) else {
        return default();
    };
    let Some(columns) = data.pointer("/touch_dashboard/columns") else {
        return default();
    };
    let read = |side: &str, i: usize| -> String {
        columns
            .get(side)
            .and_then(Value::as_array)
            .and_then(|a| a.get(i))
            .and_then(Value::as_str)
            .unwrap_or("")
            .to_owned()
    };
    normalize([
        read("left", 0),
        read("left", 1),
        read("right", 0),
        read("right", 1),
    ])
}

fn normalize(input: [String; 4]) -> [String; 4] {
    let allowed = ["interactions", "auto_macros", "macros", "music"];
    let mut columns = [Vec::<String>::new(), Vec::<String>::new()];
    for (col, slots) in columns.iter_mut().zip(input.as_chunks::<2>().0) {
        for slot in slots {
            if allowed.contains(&slot.as_str()) && !col.contains(slot) {
                col.push(slot.clone());
            }
        }
    }
    let [left, right] = &mut columns;
    right.retain(|name| !left.contains(name));
    [
        columns[0].first().cloned().unwrap_or_default(),
        columns[0].get(1).cloned().unwrap_or_default(),
        columns[1].first().cloned().unwrap_or_default(),
        columns[1].get(1).cloned().unwrap_or_default(),
    ]
}

pub(crate) fn selected_names(kind: &str) -> Vec<String> {
    let Ok(text) = fs::read_to_string(path()) else {
        return Vec::new();
    };
    let Ok(data) = serde_json::from_str::<Value>(&text) else {
        return Vec::new();
    };
    data.pointer(&format!("/touch_dashboard/{kind}"))
        .and_then(Value::as_array)
        .map(|a| {
            a.iter()
                .filter_map(Value::as_str)
                .map(str::to_owned)
                .take(4)
                .collect()
        })
        .unwrap_or_default()
}

pub(crate) fn wallpaper() -> String {
    fs::read_to_string(path())
        .ok()
        .and_then(|s| serde_json::from_str::<Value>(&s).ok())
        .and_then(|v| {
            v.get("touch_wallpaper")
                .and_then(Value::as_str)
                .map(str::to_owned)
        })
        .unwrap_or_default()
}

pub(crate) fn assets_dir() -> PathBuf {
    super::directory().join("assets")
}

pub(crate) fn wallpaper_path(relative: &str) -> Option<PathBuf> {
    use std::path::Component;
    let relative = relative.trim().trim_start_matches('/');
    let path = std::path::Path::new(relative);
    if relative.is_empty()
        || path
            .components()
            .any(|component| !matches!(component, Component::Normal(_)))
    {
        return None;
    }
    let full = assets_dir().join(path);
    if full.is_file() {
        Some(full)
    } else {
        None
    }
}

pub(crate) fn wallpaper_files(keep_scanning: impl Fn() -> bool) -> Vec<String> {
    fn scan(
        dir: &std::path::Path,
        root: &std::path::Path,
        out: &mut Vec<String>,
        keep_scanning: &impl Fn() -> bool,
    ) {
        let Ok(entries) = fs::read_dir(dir) else {
            return;
        };
        for entry in entries.flatten().take_while(|_| keep_scanning()) {
            let path = entry.path();
            if path
                .file_name()
                .is_some_and(|n| n.to_string_lossy().eq_ignore_ascii_case("category_library"))
            {
                continue;
            }
            if entry.file_type().is_ok_and(|kind| kind.is_dir()) {
                scan(&path, root, out, keep_scanning);
            } else if path.extension().is_some_and(|ext| {
                ["png", "jpg", "jpeg", "webp"]
                    .contains(&ext.to_string_lossy().to_ascii_lowercase().as_str())
            }) {
                if let Ok(relative) = path.strip_prefix(root) {
                    out.push(relative.to_string_lossy().replace('\\', "/"));
                }
            }
        }
    }
    let root = assets_dir();
    let mut results = Vec::new();
    scan(&root, &root, &mut results, &keep_scanning);
    results.sort();
    results
}

pub(crate) fn save_full(
    input: [String; 4],
    macros: &[String],
    auto_macros: &[String],
    wallpaper: &str,
) -> io::Result<[String; 4]> {
    // Writes all editor values in a single atomic rename, preserving unrelated settings.
    let normalized = normalize(input);
    let mut data = read_settings()?;
    if !wallpaper.is_empty() && wallpaper_path(wallpaper).is_none() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "Wallpaper is missing or path is unsafe",
        ));
    }
    let left: Vec<_> = normalized[0..2]
        .iter()
        .filter(|s| !s.is_empty())
        .cloned()
        .collect();
    let right: Vec<_> = normalized[2..4]
        .iter()
        .filter(|s| !s.is_empty())
        .cloned()
        .collect();
    data["touch_dashboard"] = json!({"version": 1, "columns": {"left": left, "right": right},
        "macro_names": macros.iter().take(4).collect::<Vec<_>>(),
        "auto_macro_names": auto_macros.iter().take(4).collect::<Vec<_>>()});
    data["touch_wallpaper"] = json!(wallpaper);
    write_settings(&data)?;
    Ok(normalized)
}

fn read_settings() -> io::Result<Value> {
    let target = path();
    let data = match fs::read_to_string(&target) {
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

fn write_settings(data: &Value) -> io::Result<()> {
    let target = path();
    if let Some(parent) = target.parent() {
        fs::create_dir_all(parent)?;
    }
    let temp = target.with_extension("json.tmp");
    fs::write(
        &temp,
        format!(
            "{}\n",
            serde_json::to_string_pretty(&data).map_err(io::Error::other)?
        ),
    )?;
    fs::rename(&temp, target)?;
    Ok(())
}

pub(crate) fn language() -> String {
    read_settings()
        .ok()
        .and_then(|v| v["language"].as_str().map(str::to_owned))
        .filter(|lang| lang == "de")
        .unwrap_or_else(|| "en".into())
}

pub(crate) fn save_language(lang: &str) -> io::Result<()> {
    let mut settings = read_settings()?;
    settings["language"] = json!(lang);
    write_settings(&settings)
}
