//! Dashboard editor: card selection, four-item macro pickers, wallpapers and persistence.
use crate::{config::dashboard, state::store::Store, App, PickerEntry};
use slint::{ComponentHandle, ModelRc, SharedString, VecModel};
use std::{
    cell::RefCell,
    rc::Rc,
    sync::{Arc, Mutex},
};

#[derive(Default)]
struct Editor {
    kind: String,
    search: String,
    draft_macros: Vec<String>,
    draft_auto_macros: Vec<String>,
    picker_selection: Vec<String>,
    draft_wallpaper: String,
}

fn slots(ui: &App) -> [String; 4] {
    [
        ui.get_edit_left_0().to_string(),
        ui.get_edit_left_1().to_string(),
        ui.get_edit_right_0().to_string(),
        ui.get_edit_right_1().to_string(),
    ]
}

fn set_slots(ui: &App, slots: &[String; 4]) {
    ui.set_left_slot_0(slots[0].clone().into());
    ui.set_left_slot_1(slots[1].clone().into());
    ui.set_right_slot_0(slots[2].clone().into());
    ui.set_right_slot_1(slots[3].clone().into());
}

fn set_draft_slots(ui: &App, slots: &[String; 4]) {
    ui.set_edit_left_0(slots[0].clone().into());
    ui.set_edit_left_1(slots[1].clone().into());
    ui.set_edit_right_0(slots[2].clone().into());
    ui.set_edit_right_1(slots[3].clone().into());
}

fn summaries(ui: &App, draft: &Editor) {
    ui.set_dashboard_selected_macros(format!("Selected {}/4", draft.draft_macros.len()).into());
    ui.set_dashboard_selected_auto_macros(
        format!("Selected {}/4", draft.draft_auto_macros.len()).into(),
    );
    let label = if draft.draft_wallpaper.is_empty() {
        "No wallpaper".to_owned()
    } else {
        draft
            .draft_wallpaper
            .rsplit('/')
            .next()
            .unwrap_or("")
            .to_owned()
    };
    ui.set_wallpaper_label(label.into());
}

/// Decode image formats including WebP in Rust, rather than relying on Slint's
/// file loader (which does not necessarily include a WebP decoder).
fn load_asset(path: &std::path::Path) -> slint::Image {
    use slint::{Rgb8Pixel, SharedPixelBuffer};
    let Ok(reader) = image::ImageReader::open(path) else {
        return slint::Image::default();
    };
    let Ok(decoded) = reader.decode() else {
        return slint::Image::default();
    };
    // Limit large wallpapers to the actual touch display size, avoiding huge buffers.
    let scaled = decoded.resize(1920, 1080, image::imageops::FilterType::Triangle);
    let rgb = scaled.to_rgb8();
    let pixels =
        SharedPixelBuffer::<Rgb8Pixel>::clone_from_slice(rgb.as_raw(), rgb.width(), rgb.height());
    slint::Image::from_rgb8(pixels)
}

pub(crate) fn set_wallpaper_image(ui: &App, wallpaper: &str) {
    let path = dashboard::wallpaper_path(wallpaper);
    crate::theme::wallpaper(ui, path.clone());
    let img = path.map(|p| load_asset(&p)).unwrap_or_default();
    ui.set_wallpaper_image(img);
}

fn candidates(kind: &str, store: &Arc<Mutex<Store>>) -> Vec<String> {
    if kind.starts_with("slot:") {
        return vec!["Empty", "Interactions", "Auto Macros", "Macros", "Music"]
            .into_iter()
            .map(str::to_owned)
            .collect();
    }
    if kind == "wallpaper" {
        let mut files = vec!["No wallpaper".to_owned()];
        files.extend(dashboard::wallpaper_files());
        return files;
    }
    let Ok(store) = store.lock() else {
        return vec![];
    };
    let mut result: Vec<String> = if kind == "macros" {
        store
            .macros
            .iter()
            .filter(|s| {
                !["event_", "channel_point_", "command_"]
                    .iter()
                    .any(|prefix| s.starts_with(prefix))
            })
            .cloned()
            .collect()
    } else {
        store
            .auto_macros
            .iter()
            .filter_map(|item| item.get("name").and_then(serde_json::Value::as_str))
            .map(str::to_owned)
            .collect()
    };
    result.sort();
    result.dedup();
    result
}

fn display(ui: &App, editor: &Editor, store: &Arc<Mutex<Store>>) {
    let options = candidates(&editor.kind, store);
    let search = editor.search.to_ascii_lowercase();
    let entries: Vec<PickerEntry> = options
        .iter()
        .filter(|name| search.is_empty() || name.to_ascii_lowercase().contains(&search))
        .map(|name| {
            let selected = if editor.kind == "wallpaper" {
                (name == "No wallpaper" && editor.draft_wallpaper.is_empty())
                    || *name == editor.draft_wallpaper
            } else if editor.kind.starts_with("slot:") {
                let index = slot_index(&editor.kind).unwrap_or(0);
                let raw = slots(ui)[index].clone();
                name == card_label(&raw)
            } else {
                editor.picker_selection.contains(name)
            };
            let thumbnail = if editor.kind == "wallpaper" {
                dashboard::wallpaper_path(name)
                    .map(|path| load_asset(&path))
                    .unwrap_or_default()
            } else {
                slint::Image::default()
            };
            PickerEntry {
                name: SharedString::from(name.as_str()),
                selected,
                thumbnail,
            }
        })
        .collect();
    ui.set_dashboard_picker_items(ModelRc::new(VecModel::from(entries)));
}

fn slot_index(kind: &str) -> Option<usize> {
    match kind {
        "slot:left-0" => Some(0),
        "slot:left-1" => Some(1),
        "slot:right-0" => Some(2),
        "slot:right-1" => Some(3),
        _ => None,
    }
}

fn card_label(raw: &str) -> &str {
    match raw {
        "interactions" => "Interactions",
        "auto_macros" => "Auto Macros",
        "macros" => "Macros",
        "music" => "Music",
        _ => "Empty",
    }
}
fn card_value(label: &str) -> &str {
    match label {
        "Interactions" => "interactions",
        "Auto Macros" => "auto_macros",
        "Macros" => "macros",
        "Music" => "music",
        _ => "",
    }
}

pub(crate) fn install(ui: &App, store: Arc<Mutex<Store>>) {
    let initial = dashboard::load();
    set_slots(ui, &initial);
    let editor = Rc::new(RefCell::new(Editor::default()));
    {
        let weak = ui.as_weak();
        let draft = editor.clone();
        ui.on_dashboard_editor_open(move || {
            if let Some(ui) = weak.upgrade() {
                let mut state = draft.borrow_mut();
                state.draft_macros = dashboard::selected_names("macro_names");
                state.draft_auto_macros = dashboard::selected_names("auto_macro_names");
                state.draft_wallpaper = dashboard::wallpaper();
                set_draft_slots(&ui, &dashboard::load());
                summaries(&ui, &state);
            }
        });
    }
    {
        let weak = ui.as_weak();
        let draft = editor.clone();
        ui.on_dashboard_editor_reset(move || {
            if let Some(ui) = weak.upgrade() {
                set_draft_slots(
                    &ui,
                    &[
                        "interactions".into(),
                        "auto_macros".into(),
                        "music".into(),
                        "".into(),
                    ],
                );
                let mut state = draft.borrow_mut();
                state.draft_macros.clear();
                state.draft_auto_macros.clear();
                state.draft_wallpaper.clear();
                summaries(&ui, &state);
                set_wallpaper_image(&ui, "");
            }
        });
    }
    {
        let weak = ui.as_weak();
        let draft = editor.clone();
        let source = store.clone();
        ui.on_dashboard_open_picker(move |kind| {
            if let Some(ui) = weak.upgrade() {
                let mut state = draft.borrow_mut();
                state.kind = kind.to_string();
                state.search.clear();
                state.picker_selection = if kind == "macros" {
                    state.draft_macros.clone()
                } else if kind == "auto_macros" {
                    state.draft_auto_macros.clone()
                } else {
                    vec![]
                };
                ui.set_dashboard_picker_search("".into());
                let needs_keyboard = kind == "macros" || kind == "auto_macros";
                ui.set_dashboard_picker_kind(kind);
                display(&ui, &state, &source);
                ui.set_touch_keyboard_open(needs_keyboard);
                ui.set_dashboard_picker_open(true);
            }
        });
    }
    {
        let weak = ui.as_weak();
        let draft = editor.clone();
        let source = store.clone();
        ui.on_dashboard_filter(move |search| {
            if let Some(ui) = weak.upgrade() {
                let mut state = draft.borrow_mut();
                state.search = search.to_string();
                display(&ui, &state, &source);
            }
        });
    }
    {
        let weak = ui.as_weak();
        let draft = editor.clone();
        let source = store.clone();
        ui.on_keyboard_input(move |key| {
            let Some(ui) = weak.upgrade() else {
                return;
            };
            if !ui.get_dashboard_picker_open() {
                let wifi = !ui.get_wifi_target().is_empty();
                let mut text = if wifi {
                    ui.get_wifi_password()
                } else {
                    ui.get_search()
                }
                .to_string();
                if key == "backspace" {
                    text.pop();
                } else {
                    text.push_str(&key);
                }
                if wifi {
                    ui.set_wifi_password(text.into());
                } else {
                    ui.set_search(text.into());
                }
                return;
            }
            let mut state = draft.borrow_mut();
            if key.as_str() == "backspace" {
                state.search.pop();
            } else {
                state.search.push_str(key.as_str());
            }
            ui.set_dashboard_picker_search(state.search.clone().into());
            display(&ui, &state, &source);
        });
    }
    {
        let weak = ui.as_weak();
        let draft = editor.clone();
        let source = store.clone();
        ui.on_dashboard_select_option(move |name| {
            if let Some(ui) = weak.upgrade() {
                let mut state = draft.borrow_mut();
                let name = name.to_string();
                if let Some(index) = slot_index(&state.kind) {
                    let mut values = slots(&ui);
                    let selected = card_value(&name).to_string();
                    // Keep one occurrence per card and reserve a whole column for Music.
                    for (i, value) in values.iter_mut().enumerate() {
                        if i != index && *value == selected && !selected.is_empty() {
                            value.clear();
                        }
                    }
                    if selected == "music" {
                        values[index / 2 * 2] = "music".into();
                        values[index / 2 * 2 + 1].clear();
                    } else {
                        if values[index / 2 * 2] == "music" {
                            values[index / 2 * 2].clear();
                        }
                        values[index] = selected;
                    }
                    set_draft_slots(&ui, &values);
                    ui.set_dashboard_picker_open(false);
                    ui.set_touch_keyboard_open(false);
                } else if state.kind == "wallpaper" {
                    state.draft_wallpaper = if name == "No wallpaper" {
                        "".into()
                    } else {
                        name
                    };
                    summaries(&ui, &state);
                    set_wallpaper_image(&ui, &state.draft_wallpaper);
                    ui.set_dashboard_picker_open(false);
                    ui.set_touch_keyboard_open(false);
                } else {
                    if let Some(index) = state.picker_selection.iter().position(|n| n == &name) {
                        state.picker_selection.remove(index);
                    } else if state.picker_selection.len() < 4 {
                        state.picker_selection.push(name);
                    }
                    display(&ui, &state, &source);
                }
            }
        });
    }
    {
        let weak = ui.as_weak();
        let draft = editor.clone();
        ui.on_dashboard_apply_picker(move || {
            if let Some(ui) = weak.upgrade() {
                let mut state = draft.borrow_mut();
                let selection = state.picker_selection.clone();
                if state.kind == "macros" {
                    state.draft_macros = selection;
                } else if state.kind == "auto_macros" {
                    state.draft_auto_macros = selection;
                }
                summaries(&ui, &state);
                ui.set_dashboard_picker_open(false);
            }
        });
    }
    {
        let weak = ui.as_weak();
        let draft = editor.clone();
        let source = store.clone();
        ui.on_dashboard_save(move |a, b, c, d| {
            if let Some(ui) = weak.upgrade() {
                let state = draft.borrow();
                match dashboard::save_full(
                    [a.to_string(), b.to_string(), c.to_string(), d.to_string()],
                    &state.draft_macros,
                    &state.draft_auto_macros,
                    &state.draft_wallpaper,
                ) {
                    Ok(saved) => {
                        set_slots(&ui, &saved);
                        if let Ok(guard) = source.lock() {
                            let names: Vec<SharedString> = state
                                .draft_macros
                                .iter()
                                .filter(|name| guard.macros.contains(name))
                                .map(|s| SharedString::from(s.as_str()))
                                .collect();
                            ui.set_dashboard_macro_list(ModelRc::new(VecModel::from(names)));
                            ui.set_dashboard_auto_macros(crate::state::models::auto_macro_rows(
                                &guard.auto_macros,
                            ));
                        }
                        ui.set_dashboard_editing(false);
                        ui.set_feedback("Dashboard saved".into());
                    }
                    Err(err) => ui.set_feedback(format!("Save failed: {err}").into()),
                }
            }
        });
    }
    {
        let weak = ui.as_weak();
        ui.on_dashboard_cancel(move || {
            if let Some(ui) = weak.upgrade() {
                set_wallpaper_image(&ui, &dashboard::wallpaper());
                ui.set_dashboard_picker_open(false);
            }
        });
    }
    set_wallpaper_image(ui, &dashboard::wallpaper());
    ui.set_dashboard_macro_list(ModelRc::new(VecModel::from(
        dashboard::selected_names("macro_names")
            .iter()
            .map(|s| SharedString::from(s.as_str()))
            .collect::<Vec<_>>(),
    )));
    let weak = ui.as_weak();
    ui.on_power_action(move |action| {
        let result = match action.as_str() {
            "poweroff" => std::process::Command::new("systemctl")
                .arg("poweroff")
                .spawn(),
            "reboot" => std::process::Command::new("systemctl")
                .arg("reboot")
                .spawn(),
            "restart-backend" => std::process::Command::new("systemctl")
                .args(["--user", "restart", "stream-overlord.service"])
                .spawn(),
            _ => return,
        };
        if let Some(ui) = weak.upgrade() {
            ui.set_power_menu_open(false);
            if let Err(err) = result {
                ui.set_feedback(format!("Power action failed: {err}").into());
            }
        }
    });
}
