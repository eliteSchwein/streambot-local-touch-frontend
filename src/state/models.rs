use crate::state::presentation::string_field;
use crate::{AutoMacroEntry, InteractionEntry};
use serde_json::Value;
use slint::VecModel;

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
            let mut meta = format!(
                "{} · {}",
                if source.is_empty() { "Other" } else { &source },
                if state.is_empty() { "Queued" } else { &state }
            );
            if eta > 0.0 {
                meta.push_str(&format!(" · {}s", eta.ceil() as i64));
            }
            if let Some(alerts) = item
                .get("alert_count")
                .and_then(Value::as_u64)
                .filter(|n| *n > 0)
            {
                meta.push_str(&format!(" · Alerts {alerts}"));
            }
            InteractionEntry {
                name: string_field(item, &["name"]).into(),
                meta: meta.into(),
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
    let selected = crate::config::dashboard::selected_names("auto_macro_names");
    let rows: Vec<AutoMacroEntry> = items
        .iter()
        .filter(|item| {
            item.get("name")
                .and_then(Value::as_str)
                .is_some_and(|name| selected.iter().any(|s| s == name))
        })
        .take(4)
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
