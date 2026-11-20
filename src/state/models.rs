use crate::state::presentation::string_field;
use crate::{App, AutoMacroEntry, DashboardMacroEntry, DashboardMacroSelection, InteractionEntry};
use serde_json::Value;
use slint::{Model, ModelRc, SharedString, VecModel};

pub(crate) fn interaction_rows(items: &[Value]) -> slint::ModelRc<InteractionEntry> {
    let rows: Vec<InteractionEntry> = items
        .iter()
        .map(|item| {
            let state = string_field(item, &["state"]);
            let source = string_field(item, &["source"]);
            let duration = item.get("duration").and_then(Value::as_f64).unwrap_or(0.0);
            let eta = item
                .get("eta_seconds")
                .and_then(Value::as_f64)
                .unwrap_or(0.0);
            let progress = if duration > 0.0 {
                ((duration - eta) / duration).clamp(0.0, 1.0) as f32
            } else {
                0.0
            };
            InteractionEntry {
                name: string_field(item, &["name"]).into(),
                state: if state.is_empty() {
                    "queued".into()
                } else {
                    state.as_str().into()
                },
                source: if source.is_empty() {
                    "other".into()
                } else {
                    source.into()
                },
                eta: eta.ceil() as i32,
                alerts: item["alert_count"]
                    .as_u64()
                    .unwrap_or_default()
                    .min(i32::MAX as u64) as i32,
                uuid: string_field(item, &["uuid"]).into(),
                active: state == "active",
                failed: state == "failed",
                progress,
            }
        })
        .collect();
    slint::ModelRc::new(VecModel::from(rows))
}

pub(crate) fn auto_macro_rows(items: &[Value]) -> slint::ModelRc<AutoMacroEntry> {
    let rows: Vec<AutoMacroEntry> = items
        .iter()
        .map(|item| {
            let enabled = item
                .get("enabled")
                .and_then(Value::as_bool)
                .unwrap_or(false);
            let temporary = item
                .get("temporary_interval_ms")
                .and_then(Value::as_f64)
                .unwrap_or(0.0);
            let interval = if temporary > 0.0 {
                temporary / 1000.0
            } else {
                item.get("interval").and_then(Value::as_f64).unwrap_or(1.0)
            }
            .max(0.05);
            let remaining = item
                .get("current_interval")
                .and_then(Value::as_f64)
                .unwrap_or(interval)
                .clamp(0.0, interval);
            AutoMacroEntry {
                name: string_field(item, &["name"]).into(),
                enabled,
                progress: if enabled {
                    (remaining / interval) as f32
                } else {
                    0.0
                },
            }
        })
        .collect();
    slint::ModelRc::new(VecModel::from(rows))
}

pub(crate) fn dashboard_macros(app: &App, names: Vec<SharedString>) {
    let previous = app.get_dashboard_macro_list();
    let entries: Vec<_> = names
        .into_iter()
        .map(|name| {
            previous
                .iter()
                .find(|row| row.name == name)
                .unwrap_or_else(|| DashboardMacroEntry {
                    name,
                    ..Default::default()
                })
        })
        .collect();
    if previous.iter().ne(entries.iter().cloned()) {
        app.set_dashboard_macro_list(slint::ModelRc::new(VecModel::from(entries)));
    }
}

pub(crate) fn macro_run_state(app: &App, name: &str, ticket: i32, state: &str) {
    let mut entries: Vec<_> = app.get_dashboard_macro_list().iter().collect();
    if let Some(row) = entries.iter_mut().find(|row| row.name.as_str() == name) {
        if state == "loading" || row.ticket == ticket {
            row.ticket = ticket;
            row.state = state.into();
            // Rebind the per-card selections, including every card that displays this macro.
            app.set_dashboard_macro_list(ModelRc::new(VecModel::from(entries)));
        }
    }
}

pub(crate) fn selected_macro_rows<T: Clone + 'static>(
    source: ModelRc<T>,
    selection: DashboardMacroSelection,
    limit: i32,
    name: impl Fn(&T) -> &SharedString,
    show_defaults: bool,
) -> ModelRc<T> {
    let limit = limit.max(0) as usize;
    let rows: Vec<T> = if selection.configured {
        selection
            .names
            .iter()
            .filter_map(|selected| source.iter().find(|entry| name(entry) == &selected))
            .take(limit)
            .collect()
    } else if show_defaults {
        source.iter().take(limit).collect()
    } else {
        Vec::new()
    };
    ModelRc::new(VecModel::from(rows))
}
