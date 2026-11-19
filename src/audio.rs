use crate::{ui_bridge::ui_event, App, AudioEntry, AudioLink};
use serde_json::Value;
use slint::{Model, ModelRc, VecModel};
use std::process::Command;

fn identifier(value: &Value, keys: &[&str]) -> String {
    keys.iter()
        .find_map(|key| match &value[key] {
            Value::String(s) if !s.is_empty() => Some(s.clone()),
            Value::Number(n) => Some(n.to_string()),
            _ => None,
        })
        .unwrap_or_default()
}

fn contains(value: &Value, name: &str) -> bool {
    value
        .as_array()
        .is_some_and(|items| items.iter().any(|item| item.as_str() == Some(name)))
}

pub(crate) fn rows(interfaces: &Value, outputs: &Value) -> ModelRc<AudioEntry> {
    let outputs = outputs
        .as_array()
        .or_else(|| outputs["outputs"].as_array())
        .map(Vec::as_slice)
        .unwrap_or_default();
    let mut rows = Vec::new();
    let virtual_devices = interfaces
        .get("interfaces")
        .unwrap_or(interfaces)
        .as_object()
        .into_iter()
        .flatten();
    let output_id = |output: &Value| {
        identifier(
            output,
            &[
                "name",
                "node_name",
                "nodeName",
                "description",
                "id",
                "index",
            ],
        )
    };
    for (id, device, physical) in virtual_devices
        .map(|(k, v)| (k.clone(), v, false))
        .chain(outputs.iter().map(|v| (output_id(v), v, true)))
    {
        if id.is_empty() {
            continue;
        }
        let number =
            |key: &str, fallback: f32| device[key].as_f64().map(|v| v as f32).unwrap_or(fallback);
        let volume = number(
            "current_volume",
            number("default_volume", number("volume", 0.)),
        );
        let mut links = Vec::new();
        let routable =
            !physical && (device["pipewire_sink"] == true || device["pipewire_sink"] == "true");
        if routable {
            for output in outputs {
                let name = output_id(output);
                if name.is_empty() {
                    continue;
                }
                let linked = [
                    "linked_output",
                    "actual_linked_output",
                    "audio_output",
                    "output",
                ]
                .iter()
                .any(|k| device[k].as_str() == Some(&name))
                    || ["linked_outputs", "actual_linked_outputs", "audio_outputs"]
                        .iter()
                        .any(|k| contains(&device[k], &name))
                    || ["linked_interfaces", "active_interfaces", "interfaces"]
                        .iter()
                        .any(|k| contains(&output[k], &id));
                links.push(AudioLink {
                    id: name.as_str().into(),
                    label: output["description"].as_str().unwrap_or(&name).into(),
                    linked,
                    present: true,
                    default_output: ["is_default", "default", "isDefault"]
                        .iter()
                        .any(|key| output[*key] == true),
                    volume: device["link_volumes"][&name]
                        .as_f64()
                        .map(|n| n as f32)
                        .unwrap_or(volume),
                });
            }
            for name in device["linked_outputs"]
                .as_array()
                .into_iter()
                .flatten()
                .filter_map(Value::as_str)
            {
                if !links.iter().any(|link| link.id.as_str() == name) {
                    links.push(AudioLink {
                        id: name.into(),
                        label: name.into(),
                        linked: true,
                        present: false,
                        default_output: false,
                        volume,
                    });
                }
            }
        }
        let minimum = number("min_range", 0.);
        rows.push(AudioEntry {
            id: id.as_str().into(),
            label: if physical {
                device["description"].as_str().unwrap_or(&id)
            } else {
                &id
            }
            .into(),
            subtitle: if physical {
                id.clone()
            } else {
                device["sink_name"]
                    .as_str()
                    .map(str::to_owned)
                    .unwrap_or_else(|| format!("streambot_{id}"))
            }
            .into(),
            physical,
            volume,
            routable,
            muted: device["muted"] == true || (!physical && volume <= minimum),
            restore: if volume > 0. {
                volume
            } else {
                number("default_volume", 0.2).max(0.01)
            },
            minimum,
            maximum: number("max_range", 1.),
            step: if physical {
                0.05
            } else {
                number("steps_range", 0.01).max(0.001)
            },
            per_link: routable && device["per_link_control"] == true,
            links: ModelRc::new(VecModel::from(links)),
        });
    }
    ModelRc::new(VecModel::from(rows))
}

pub(crate) fn physical_volume(ui: slint::Weak<App>, id: String, volume: Option<f32>) {
    use std::sync::{mpsc, OnceLock};
    type CommandRequest = (slint::Weak<App>, String, Option<f32>);
    static WORKER: OnceLock<mpsc::Sender<CommandRequest>> = OnceLock::new();
    let worker = WORKER.get_or_init(|| {
        let (tx, rx) = mpsc::channel::<CommandRequest>();
        std::thread::spawn(move || {
            for (ui, id, volume) in rx {
                apply_physical_volume(ui, id, volume);
            }
        });
        tx
    });
    let _ = worker.send((ui, id, volume));
}

fn apply_physical_volume(ui: slint::Weak<App>, id: String, volume: Option<f32>) {
    let (action, value) = match volume {
        Some(v) => ("set-sink-volume", format!("{}%", (v * 100.).round())),
        None => ("set-sink-mute", "toggle".into()),
    };
    match Command::new("pactl").args([action, &id, &value]).output() {
        Ok(result) if result.status.success() => (),
        result => {
            let message = match result {
                Ok(output) => String::from_utf8_lossy(&output.stderr).into_owned(),
                Err(e) => e.to_string(),
            };
            ui_event(&ui, move |app| app.set_feedback(message.into()));
        }
    }
}

pub(crate) fn update_rows(app: &App, next: ModelRc<AudioEntry>) {
    let current = app.get_audio_interfaces();
    let Some(model) = current.as_any().downcast_ref::<VecModel<AudioEntry>>() else {
        app.set_audio_interfaces(next);
        return;
    };
    if !current
        .iter()
        .map(|row| (row.id, row.physical))
        .eq(next.iter().map(|row| (row.id, row.physical)))
    {
        app.set_audio_interfaces(next);
        return;
    }
    for (index, (before, mut after)) in current.iter().zip(next.iter()).enumerate() {
        if before.links.iter().eq(after.links.iter()) {
            after.links = before.links.clone();
        }
        if before != after {
            model.set_row_data(index, after);
        }
    }
}
