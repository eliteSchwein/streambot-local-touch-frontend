use serde_json::Value;

pub(crate) fn string_field(v: &Value, keys: &[&str]) -> String {
    keys.iter()
        .find_map(|key| v.get(*key).and_then(Value::as_str))
        .unwrap_or("")
        .to_owned()
}
pub(crate) fn summary(v: &Value) -> String {
    if v.is_null() {
        "Waiting for state…".into()
    } else {
        serde_json::to_string_pretty(v)
            .unwrap_or_default()
            .chars()
            .take(1200)
            .collect()
    }
}

pub(crate) fn time_label(v: Option<&Value>) -> String {
    let ms = v.and_then(Value::as_f64).unwrap_or(0.0).max(0.0);
    let seconds = (ms / 1000.0).floor() as u64;
    format!("{}:{:02}", seconds / 60, seconds % 60)
}
