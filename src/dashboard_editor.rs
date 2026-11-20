//! Dashboard editor: card selection, per-slot macro pickers, wallpapers and persistence.
use crate::{
    config::dashboard::{self, Layout, MacroSelections},
    state::store::Store,
    App, DashboardMacroSelection, PickerEntry,
};
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
    selections: MacroSelections,
    picker_slot: Option<usize>,
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

pub(super) fn set_macro_selections(ui: &App, selections: &MacroSelections) {
    let model: Vec<DashboardMacroSelection> = selections
        .iter()
        .map(|selection| {
            let names = selection
                .iter()
                .flatten()
                .map(|name| SharedString::from(name.as_str()))
                .collect::<Vec<_>>();
            DashboardMacroSelection {
                configured: selection.is_some(),
                names: ModelRc::new(VecModel::from(names)),
            }
        })
        .collect();
    ui.set_dashboard_macro_selections(ModelRc::new(VecModel::from(model)));
}

fn set_wallpaper_label(ui: &App, wallpaper: &str) {
    ui.set_wallpaper_label(wallpaper.rsplit('/').next().unwrap_or("").into());
}

pub(crate) use crate::wallpaper::set as set_wallpaper_image;

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
    let id = kind
        .strip_prefix("slot:")
        .or_else(|| kind.strip_prefix("entries:"))?;
    dashboard::SLOT_IDS.iter().position(|slot| *slot == id)
}

fn selection_limit(ui: &App, index: usize) -> usize {
    dashboard::macro_limit(!slots(ui)[index ^ 1].is_empty())
}

pub(crate) fn install(ui: &App, store: Arc<Mutex<Store>>) {
    let initial = dashboard::load();
    set_slots(ui, &initial.slots);
    set_macro_selections(ui, &initial.selections);
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
                let layout = dashboard::load();
                state.selections = layout.selections;
                state.draft_wallpaper = dashboard::wallpaper();
                set_draft_slots(&ui, &layout.slots);
                set_macro_selections(&ui, &state.selections);
                set_wallpaper_label(&ui, &state.draft_wallpaper);
            }
        });
    }
    {
        let weak = ui.as_weak();
        let draft = editor.clone();
        ui.on_dashboard_editor_reset(move || {
            if let Some(ui) = weak.upgrade() {
                let layout = Layout::default();
                set_draft_slots(&ui, &layout.slots);
                let mut state = draft.borrow_mut();
                state.selections = layout.selections;
                state.draft_wallpaper.clear();
                set_macro_selections(&ui, &state.selections);
                set_wallpaper_label(&ui, "");
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
                let (picker_slot, kind) = if kind.starts_with("entries:") {
                    let Some(index) = slot_index(&kind) else {
                        return;
                    };
                    let card = slots(&ui)[index].clone();
                    if !dashboard::is_macro_card(&card) {
                        return;
                    }
                    (Some(index), card)
                } else {
                    (None, kind.to_string())
                };
                let mut state = draft.borrow_mut();
                state.kind = kind;
                state.search.clear();
                state.picker_slot = picker_slot;
                state.picker_selection.clear();
                if let Some(index) = picker_slot {
                    let limit = selection_limit(&ui, index);
                    state.picker_selection = state.selections[index]
                        .iter()
                        .flatten()
                        .take(limit)
                        .cloned()
                        .collect();
                    ui.set_dashboard_picker_limit(limit as i32);
                }
                ui.set_dashboard_picker_search("".into());
                let wallpaper = state.kind == "wallpaper";
                ui.set_dashboard_picker_kind(state.kind.as_str().into());
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
                    if !dashboard::is_macro_card(&name) && !name.is_empty() {
                        for (i, value) in values.iter_mut().enumerate() {
                            if i != index && *value == name {
                                value.clear();
                            }
                        }
                    }
                    if values[index] != name {
                        state.selections[index] = None;
                        values[index] = name;
                    }
                    set_draft_slots(&ui, &values);
                    set_macro_selections(&ui, &state.selections);
                    ui.set_dashboard_picker_open(false);
                    ui.set_touch_keyboard_open(false);
                } else if state.kind == "wallpaper" {
                    state.draft_wallpaper = name;
                    set_wallpaper_label(&ui, &state.draft_wallpaper);
                    set_wallpaper_image(&ui, &state.draft_wallpaper);
                    ui.set_dashboard_picker_open(false);
                    ui.set_touch_keyboard_open(false);
                } else if let Some(slot) = state.picker_slot {
                    if let Some(index) = state.picker_selection.iter().position(|n| n == &name) {
                        state.picker_selection.remove(index);
                    } else if state.picker_selection.len() < selection_limit(&ui, slot) {
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
                if let Some(slot) = state.picker_slot {
                    let limit = selection_limit(&ui, slot);
                    let selection: Vec<_> =
                        state.picker_selection.iter().take(limit).cloned().collect();
                    let changed = state.selections[slot]
                        .as_ref()
                        .is_none_or(|previous| previous.iter().take(limit).ne(selection.iter()));
                    if changed {
                        state.selections[slot] = Some(selection);
                    }
                    set_macro_selections(&ui, &state.selections);
                }
                ui.set_dashboard_picker_open(false);
            }
        });
    }
    {
        let weak = ui.as_weak();
        let draft = editor.clone();
        ui.on_dashboard_save(move |a, b, c, d| {
            if let Some(ui) = weak.upgrade() {
                let state = draft.borrow();
                let layout = Layout {
                    slots: [a.to_string(), b.to_string(), c.to_string(), d.to_string()],
                    selections: state.selections.clone(),
                };
                match dashboard::save_full(layout, &state.draft_wallpaper) {
                    Ok(saved) => {
                        set_slots(&ui, &saved.slots);
                        set_macro_selections(&ui, &saved.selections);
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
    crate::wallpaper::restore(ui, &dashboard::wallpaper());
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
