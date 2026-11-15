use serde_json::Value;
use std::collections::BTreeMap;

fn merge(previous: &mut Value, patch: &Value) {
    if let (Some(target), Some(update)) = (previous.as_object_mut(), patch.as_object()) {
        for (key, new_value) in update {
            if let Some(old_value) = target.get_mut(key) {
                merge(old_value, new_value);
            } else {
                target.insert(key.clone(), new_value.clone());
            }
        }
    } else {
        *previous = patch.clone();
    }
}

#[derive(Default)]
pub(crate) struct Store {
    snapshots: BTreeMap<String, Value>,
    pub(crate) macros: Vec<String>,
    pub(crate) auto_macros: Vec<Value>,
    pub(crate) points: Vec<Value>,
    pub(crate) audio: Vec<String>,
    pub(crate) interactions: Vec<Value>,
}

impl Store {
    pub(crate) fn reset(&mut self) {
        self.snapshots.clear();
        self.macros.clear();
        self.auto_macros.clear();
        self.points.clear();
        self.audio.clear();
        self.interactions.clear();
    }
    pub(crate) fn accept(&mut self, method: &str, params: &Value) -> Value {
        let current = self
            .snapshots
            .entry(method.to_owned())
            .or_insert(Value::Null);
        merge(current, params);
        let state = current.clone();
        match method {
            "notify_interaction_queue" => {
                self.interactions = state
                    .as_array()
                    .or_else(|| state.get("queue").and_then(Value::as_array))
                    .cloned()
                    .unwrap_or_default();
            }
            "notify_interaction" => {
                if let Some(interaction) = params.get("interaction") {
                    if let Some(uuid) = interaction.get("uuid").and_then(Value::as_str) {
                        let action = params.get("action").and_then(Value::as_str).unwrap_or("");
                        if ["finish", "cancel", "failed"].contains(&action) {
                            self.interactions.retain(|entry| {
                                entry.get("uuid").and_then(Value::as_str) != Some(uuid)
                            });
                        } else if let Some(existing) = self
                            .interactions
                            .iter_mut()
                            .find(|entry| entry.get("uuid").and_then(Value::as_str) == Some(uuid))
                        {
                            merge(existing, interaction);
                        } else {
                            self.interactions.push(interaction.clone());
                        }
                    }
                }
            }
            "notify_macro_update" => {
                let obj = state.get("macros").unwrap_or(&state);
                self.macros = obj
                    .as_object()
                    .map(|m| m.keys().cloned().collect())
                    .unwrap_or_default();
            }
            "notify_auto_macros_update" => {
                self.auto_macros = state
                    .as_array()
                    .or_else(|| state.get("auto_macros").and_then(Value::as_array))
                    .or_else(|| state.get("autoMacros").and_then(Value::as_array))
                    .cloned()
                    .unwrap_or_default();
            }
            "notify_channel_point_update" => {
                self.points = state
                    .get("all")
                    .and_then(Value::as_array)
                    .cloned()
                    .unwrap_or_default();
            }
            "notify_audio_update" => {
                let obj = state.get("interfaces").unwrap_or(&state);
                self.audio = obj
                    .as_object()
                    .map(|m| m.keys().cloned().collect())
                    .unwrap_or_default();
            }
            _ => {}
        }
        state
    }
}
