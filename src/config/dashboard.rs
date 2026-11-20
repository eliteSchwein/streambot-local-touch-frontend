//! Local dashboard configuration compatible with Quickshell Config.qml.
use super::{read_settings, settings_path as path, write_settings};
use serde_json::{json, Value};
use std::{fs, io, path::PathBuf};

pub(crate) const SLOT_IDS: [&str; 4] = ["left-0", "left-1", "right-0", "right-1"];
pub(crate) const FULL_MACRO_LIMIT: usize = 9;
pub(crate) const STACKED_MACRO_LIMIT: usize = 4;
pub(crate) type MacroSelections = [Option<Vec<String>>; 4];

#[derive(Clone)]
pub(crate) struct Layout {
    pub(crate) slots: [String; 4],
    pub(crate) selections: MacroSelections,
}

impl Default for Layout {
    fn default() -> Self {
        Self {
            slots: ["interactions", "auto_macros", "music", ""].map(str::to_owned),
            selections: Default::default(),
        }
    }
}

pub(crate) fn is_macro_card(kind: &str) -> bool {
    matches!(kind, "macros" | "auto_macros")
}

pub(crate) fn macro_limit(stacked: bool) -> usize {
    if stacked {
        STACKED_MACRO_LIMIT
    } else {
        FULL_MACRO_LIMIT
    }
}

pub(crate) fn load() -> Layout {
    read_settings(&path()).map_or_else(|_| Layout::default(), |settings| layout_from(&settings))
}

fn layout_from(settings: &Value) -> Layout {
    let dashboard = &settings["touch_dashboard"];
    let Some(columns) = dashboard.get("columns") else {
        return Layout::default();
    };
    let slots: [String; 4] = std::array::from_fn(|index| {
        columns[if index < 2 { "left" } else { "right" }][index % 2]
            .as_str()
            .unwrap_or_default()
            .to_owned()
    });
    let selections = std::array::from_fn(|index| {
        let legacy_key = match slots[index].as_str() {
            "macros" => "macro_names",
            "auto_macros" => "auto_macro_names",
            _ => return None,
        };
        let names = |value: &Value| {
            value.as_array().map(|values| {
                let mut names = Vec::new();
                for name in values.iter().filter_map(Value::as_str) {
                    if names.len() == FULL_MACRO_LIMIT {
                        break;
                    }
                    if !names.iter().any(|entry| entry == name) {
                        names.push(name.to_owned());
                    }
                }
                names
            })
        };
        if let Some(per_slot) = dashboard.get("slot_macro_names") {
            names(&per_slot[SLOT_IDS[index]])
        } else {
            // Legacy empty Auto Macro lists show the first available entries.
            names(&dashboard[legacy_key]).filter(|names| !names.is_empty())
        }
    });
    normalize(Layout { slots, selections })
}

fn normalize(layout: Layout) -> Layout {
    let mut result = Layout {
        slots: Default::default(),
        selections: Default::default(),
    };
    let mut counts = [0; 2];
    for (index, (kind, selection)) in layout.slots.into_iter().zip(layout.selections).enumerate() {
        let macro_card = is_macro_card(&kind);
        if !macro_card
            && (!matches!(kind.as_str(), "interactions" | "music") || result.slots.contains(&kind))
        {
            continue;
        }
        let column = index / 2;
        let target = column * 2 + counts[column];
        counts[column] += 1;
        result.slots[target] = kind;
        if macro_card {
            result.selections[target] = selection.map(|mut names| {
                names.truncate(FULL_MACRO_LIMIT);
                names
            });
        }
    }
    result
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

pub(crate) fn save_full(layout: Layout, wallpaper: &str) -> io::Result<Layout> {
    // Writes all editor values in a single atomic rename, preserving unrelated settings.
    let normalized = normalize(layout);
    let target = path();
    let mut data = read_settings(&target)?;
    if !wallpaper.is_empty() && wallpaper_path(wallpaper).is_none() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "Wallpaper is missing or path is unsafe",
        ));
    }
    data["touch_dashboard"] = layout_json(&normalized);
    data["touch_wallpaper"] = json!(wallpaper);
    write_settings(&target, &data)?;
    Ok(normalized)
}

fn layout_json(layout: &Layout) -> Value {
    let column = |range: std::ops::Range<usize>| {
        layout.slots[range]
            .iter()
            .filter(|kind| !kind.is_empty())
            .cloned()
            .collect::<Vec<_>>()
    };
    let per_slot: serde_json::Map<String, Value> = SLOT_IDS
        .iter()
        .zip(&layout.selections)
        .filter_map(|(id, names)| Some((id.to_string(), json!(names.as_ref()?))))
        .collect();
    let legacy_names = |kind: &str| {
        // Older clients can read the first configured card of each type.
        layout
            .slots
            .iter()
            .position(|slot| slot == kind)
            .and_then(|index| layout.selections[index].as_ref())
            .into_iter()
            .flatten()
            .take(STACKED_MACRO_LIMIT)
            .cloned()
            .collect::<Vec<_>>()
    };
    json!({
        "version": 1,
        "columns": {"left": column(0..2), "right": column(2..4)},
        "slot_macro_names": per_slot,
        "macro_names": legacy_names("macros"),
        "auto_macro_names": legacy_names("auto_macros"),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn loads_legacy_selections_and_round_trips_independent_cards() {
        let legacy = json!({"touch_dashboard": {
            "columns": {"left": ["macros"], "right": ["auto_macros"]},
            "macro_names": ["Start"],
            "auto_macro_names": []
        }});
        let layout = layout_from(&legacy);
        assert_eq!(layout.selections[0], Some(vec!["Start".into()]));
        assert_eq!(layout.selections[2], None);

        let layout = normalize(Layout {
            slots: ["", "macros", "macros", "auto_macros"].map(str::to_owned),
            selections: [
                None,
                Some((1..=9).map(|index| format!("Macro {index}")).collect()),
                Some(vec!["Other".into()]),
                Some(Vec::new()),
            ],
        });
        let saved = layout_json(&layout);
        assert_eq!(saved["macro_names"].as_array().unwrap().len(), 4);
        let loaded = layout_from(&json!({"touch_dashboard": saved}));
        assert_eq!(loaded.slots, ["macros", "", "macros", "auto_macros"]);
        assert_eq!(loaded.selections, layout.selections);
        assert_eq!(loaded.selections[0].as_ref().unwrap().len(), 9);
    }
}

pub(crate) fn language() -> String {
    read_settings(&path())
        .ok()
        .and_then(|v| v["language"].as_str().map(str::to_owned))
        .filter(|lang| lang == "de")
        .unwrap_or_else(|| "en".into())
}

pub(crate) fn save_language(lang: &str) -> io::Result<()> {
    let target = path();
    let mut settings = read_settings(&target)?;
    settings["language"] = json!(lang);
    write_settings(&target, &settings)
}
