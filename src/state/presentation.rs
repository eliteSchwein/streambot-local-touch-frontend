use serde_json::Value;

pub(crate) fn string_field(v: &Value, keys: &[&str]) -> String {
    keys.iter()
        .find_map(|key| v.get(*key).and_then(Value::as_str))
        .unwrap_or("")
        .to_owned()
}
pub(crate) fn time_label(v: Option<&Value>) -> String {
    let ms = v.and_then(Value::as_f64).unwrap_or(0.0).max(0.0);
    let seconds = (ms / 1000.0).floor() as u64;
    format!("{}:{:02}", seconds / 60, seconds % 60)
}

fn metric(value: &Value, paths: &[&str]) -> Option<f64> {
    paths.iter().filter_map(|p| value.pointer(p)).find_map(|v| {
        v.as_f64()
            .or_else(|| v.as_str()?.parse().ok())
            .filter(|n| n.is_finite())
    })
}

fn bytes(n: f64) -> String {
    let mut size = n;
    for unit in ["B", "KiB", "MiB", "GiB", "TiB"] {
        if size < 1024. || unit == "TiB" {
            return format!("{size:.1} {unit}");
        }
        size /= 1024.;
    }
    unreachable!()
}

pub(crate) fn storage(state: &Value) -> String {
    let raw = ["content", "storage", "info", "data"]
        .iter()
        .find_map(|k| state.get(*k).filter(|v| v.is_object()))
        .unwrap_or(state);
    let mut lines = Vec::new();
    for (label, paths) in [
        (
            "Used",
            &[
                "/used",
                "/usedBytes",
                "/storageUsed",
                "/disk/used",
                "/root/used",
            ][..],
        ),
        (
            "Free",
            &[
                "/free",
                "/freeBytes",
                "/storageFree",
                "/available",
                "/disk/free",
                "/root/free",
            ],
        ),
        (
            "Total",
            &[
                "/total",
                "/totalBytes",
                "/storageTotal",
                "/disk/total",
                "/root/total",
            ],
        ),
    ] {
        if let Some(n) = metric(raw, paths) {
            lines.push(format!("{label}  {}", bytes(n)));
        }
    }
    let folders = ["folders", "directories", "paths"]
        .iter()
        .find_map(|k| raw[*k].as_object());
    for (name, value) in folders.into_iter().flatten() {
        if let Some(n) = metric(value, &[""]).filter(|n| *n > 0.) {
            lines.push(format!("{}  {}", name.replace('_', " "), bytes(n)));
        }
    }
    lines.join("\n")
}

pub(crate) fn system(state: &Value) -> String {
    let raw = ["content", "data", "info", "system_info", "systemInfo"]
        .iter()
        .find_map(|k| state.get(*k))
        .unwrap_or(state);
    let components = raw.get("components").unwrap_or(raw);
    let mut lines = Vec::new();
    for (label, unit, paths) in [
        (
            "CPU",
            "%",
            &[
                "/cpu_usage",
                "/cpuUsage",
                "/currentLoad/currentLoad",
                "/currentLoad",
                "/cpu/usage_percent",
                "/cpu/load",
                "/system_cpu_usage/cpu",
            ][..],
        ),
        (
            "CPU temperature",
            "°C",
            &[
                "/cpu_temperature",
                "/cpuTemperature/main",
                "/cpuTemperature",
                "/cpu/temp",
                "/cpu/temperature",
            ],
        ),
        (
            "RAM",
            "%",
            &[
                "/ram_usage",
                "/memory/usage_percent",
                "/memory/percent",
                "/ram/usage_percent",
            ],
        ),
        (
            "Swap",
            "%",
            &["/swap_usage", "/swap/usage_percent", "/swap/percent"],
        ),
        (
            "Internal storage",
            "%",
            &[
                "/internal_storage_usage",
                "/storage/internal/usage_percent",
                "/storage/internal/percent",
            ],
        ),
    ] {
        if let Some(n) = metric(components, paths).or_else(|| metric(raw, paths)) {
            lines.push(format!("{label}  {n:.1} {unit}"));
        }
    }
    lines.join("\n")
}

pub(crate) fn speedtest(state: &Value) -> String {
    let mut lines = vec![string_field(state, &["stage"])];
    for (label, key, unit) in [
        ("Ping", "ping_ms", "ms"),
        ("Download", "download_mbps", "Mbit/s"),
        ("Upload", "upload_mbps", "Mbit/s"),
    ] {
        let value = state[key]
            .as_f64()
            .map(|n| format!("{n:.1} {unit}"))
            .unwrap_or_else(|| "—".into());
        lines.push(format!("{label}  {value}"));
    }
    if let Some(error) = state["error"].as_str().filter(|s| !s.is_empty()) {
        lines.push(error.to_owned());
    }
    lines.join("\n")
}

pub(crate) fn updates(state: &Value) -> slint::ModelRc<crate::UpdateEntry> {
    let managers = state.get("managers").unwrap_or(state);
    let rows = managers
        .as_object()
        .into_iter()
        .flatten()
        .filter(|(_, v)| v.is_object())
        .map(|(name, v)| {
            let count = metric(
                v,
                &[
                    "/package_count",
                    "/packageCount",
                    "/updates_count",
                    "/count",
                ],
            )
            .unwrap_or_else(|| v["updates"].as_array().map_or(0, Vec::len) as f64);
            let available = v["update_available"] == true || count > 0.;
            let busy = v["checking"] == true || v["updating"] == true;
            let status = if let Some(error) = v["error"].as_str().filter(|s| !s.is_empty()) {
                error.to_string()
            } else if v["updating"] == true {
                format!(
                    "Updating · {}",
                    string_field(&v["progress"], &["message", "package", "stage"])
                )
            } else if busy {
                "Checking…".into()
            } else if count > 0. {
                format!("{count} updates")
            } else if available {
                "Update available".into()
            } else {
                string_field(v, &["current_version", "commit"])
            };
            crate::UpdateEntry {
                busy,
                id: name.as_str().into(),
                label: format!("{name}  {status}").into(),
                active: available && !busy,
            }
        })
        .collect::<Vec<_>>();
    slint::ModelRc::new(slint::VecModel::from(rows))
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    #[test]
    fn storage_includes_video_models_and_wrapped_capacity() {
        let result = storage(&json!({"data":{"disk":{"total":2048},"folders":{"webcam":1024}}}));
        assert!(result.contains("Total  2.0 KiB"));
        assert!(result.contains("webcam  1.0 KiB"));
    }
}
