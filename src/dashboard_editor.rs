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
    ui.set_dashboard_selected_macros(draft.draft_macros.len() as i32);
    ui.set_dashboard_selected_auto_macros(draft.draft_auto_macros.len() as i32);
    ui.set_wallpaper_label(
        draft
            .draft_wallpaper
            .rsplit('/')
            .next()
            .unwrap_or("")
            .into(),
    );
}

pub(crate) use crate::wallpaper::set as set_wallpaper_image;

/// The dashboard doubles as the editor, so the macro cards show the draft selection.
fn preview(ui: &App, draft: &Editor, store: &Arc<Mutex<Store>>) {
    let Ok(guard) = store.lock() else {
        return;
    };
    let names: Vec<SharedString> = draft
        .draft_macros
        .iter()
        .filter(|name| guard.macros.contains(name))
        .map(|s| SharedString::from(s.as_str()))
        .collect();
    crate::state::models::dashboard_macros(ui, names);
    ui.set_dashboard_auto_macros(crate::state::models::auto_macro_rows_for(
        &guard.auto_macros,
        &draft.draft_auto_macros,
    ));
}

fn candidates(kind: &str, store: &Arc<Mutex<Store>>) -> Vec<String> {
    if kind.starts_with("slot:") {
        return vec!["", "interactions", "auto_macros", "macros", "music"]
            .into_iter()
            .map(str::to_owned)
            .collect();
    }
    let Ok(store) = store.lock() else {
        return vec![];
    };
    let mut result: Vec<String> = if kind == "macros" {
        store
            .macros
            .iter()
            .filter(|s| crate::state::presentation::is_manual_macro(s))
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
            let selected = if editor.kind.starts_with("slot:") {
                let index = slot_index(&editor.kind).unwrap_or(0);
                let raw = slots(ui)[index].clone();
                name == &raw
            } else {
                editor.picker_selection.contains(name)
            };
            PickerEntry {
                name: SharedString::from(name.as_str()),
                selected,
                thumbnail: slint::Image::default(),
                loading: false,
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

pub(crate) fn install(ui: &App, store: Arc<Mutex<Store>>) {
    let initial = dashboard::load();
    set_slots(ui, &initial);
    let editor = Rc::new(RefCell::new(Editor::default()));
    let wallpaper_picker = crate::wallpaper::Picker::new();
    let cancel = wallpaper_picker.clone();
    ui.on_wallpaper_picker_closed(move || cancel.cancel());
    {
        let weak = ui.as_weak();
        let draft = editor.clone();
        ui.on_dashboard_editor_open(move || {
            if let Some(ui) = weak.upgrade() {
                ui.set_feedback("".into());
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
        let source = store.clone();
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
                preview(&ui, &state, &source);
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
                let wallpaper = kind == "wallpaper";
                ui.set_dashboard_picker_kind(kind);
                ui.set_dashboard_picker_open(true);
                if wallpaper {
                    wallpaper_picker.open(&ui, &state.draft_wallpaper);
                } else {
                    display(&ui, &state, &source);
                }
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
        ui.on_dashboard_select_option(move |name| {
            if let Some(ui) = weak.upgrade() {
                let mut state = draft.borrow_mut();
                let name = name.to_string();
                if let Some(index) = slot_index(&state.kind) {
                    let mut values = slots(&ui);
                    let selected = name;
                    // Keep one occurrence per card; Music turns compact when it shares a column.
                    for (i, value) in values.iter_mut().enumerate() {
                        if i != index && *value == selected && !selected.is_empty() {
                            value.clear();
                        }
                    }
                    values[index] = selected;
                    set_draft_slots(&ui, &values);
                    ui.set_dashboard_picker_open(false);
                    ui.set_touch_keyboard_open(false);
                } else if state.kind == "wallpaper" {
                    state.draft_wallpaper = name;
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
        let source = store.clone();
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
                preview(&ui, &state, &source);
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
                        preview(&ui, &state, &source);
                        ui.set_feedback("".into());
                        ui.set_dashboard_editing(false);
                    }
                    Err(err) => {
                        let label =
                            crate::i18n::text(&ui.get_language(), "dashboard_card_saved_error");
                        ui.set_feedback(format!("{label}: {err}").into());
                    }
                }
            }
        });
    }
    set_wallpaper_image(ui, &dashboard::wallpaper());
    crate::state::models::dashboard_macros(
        ui,
        dashboard::selected_names("macro_names")
            .into_iter()
            .map(SharedString::from)
            .collect(),
    );
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
                let label = crate::i18n::text(&ui.get_language(), "power_action_failed");
                ui.set_feedback(format!("{label}: {err}").into());
            }
        }
    });
}
