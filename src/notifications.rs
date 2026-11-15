use crate::{
    state::{
        models::{auto_macro_rows, interaction_rows},
        presentation::{string_field, summary, time_label},
        store::Store,
    },
    ui_bridge::ui_event,
    App,
};
use serde_json::Value;
use slint::{SharedString, VecModel};
use std::sync::{Arc, Mutex};
use tokio::sync::mpsc;

pub(crate) fn spawn(
    store: Arc<Mutex<Store>>,
    ui: slint::Weak<App>,
    mut event_rx: mpsc::UnboundedReceiver<Value>,
) {
    // Drain incoming notifications on the UI thread. A Rust store merges delta payloads
    // before the widgets render them, matching DashboardStore.qml behavior.
    let notify_store = store.clone();
    let event_ui = ui;
    tokio::spawn(async move {
        while let Some(packet) = event_rx.recv().await {
            let method = packet
                .get("method")
                .and_then(Value::as_str)
                .unwrap_or("")
                .to_string();
            if !method.starts_with("notify_") {
                continue;
            }
            let state = {
                let mut guard = match notify_store.lock() {
                    Ok(g) => g,
                    Err(_) => continue,
                };
                guard.accept(&method, packet.get("params").unwrap_or(&Value::Null))
            };
            let store2 = notify_store.clone();
            ui_event(&event_ui, move |app| {
                match method.as_str() {
                    "notify_music_update" => {
                        let song = state
                            .get("current_song")
                            .or_else(|| state.get("current_track"))
                            .unwrap_or(&state);
                        let title = string_field(song, &["title", "name"]);
                        let artist = string_field(song, &["artist", "author"]);
                        app.set_track(if title.is_empty() {
                            "No track information".into()
                        } else if artist.is_empty() {
                            title.clone().into()
                        } else {
                            format!("{title} — {artist}").into()
                        });
                        app.set_music_state(string_field(&state, &["status"]).into());
                        app.set_music_title(if title.is_empty() {
                            "No song".into()
                        } else {
                            title.into()
                        });
                        app.set_music_artist(if artist.is_empty() {
                            "Unknown artist".into()
                        } else {
                            artist.into()
                        });
                        app.set_music_playing(
                            state.get("status").and_then(Value::as_str) == Some("playing"),
                        );
                        app.set_music_shuffle(
                            state
                                .get("shuffle")
                                .and_then(Value::as_bool)
                                .unwrap_or(false),
                        );
                        app.set_music_loop(
                            state.get("loop").and_then(Value::as_bool).unwrap_or(false)
                                || state
                                    .get("loop_file")
                                    .and_then(Value::as_bool)
                                    .unwrap_or(false),
                        );
                        app.set_music_song_requests(
                            state
                                .pointer("/songrequest/enabled")
                                .and_then(Value::as_bool)
                                .unwrap_or(false),
                        );
                        app.set_music_progress(
                            state
                                .get("progress_percentage")
                                .and_then(Value::as_f64)
                                .unwrap_or(0.0)
                                .clamp(0.0, 100.0) as f32,
                        );
                        app.set_music_position(time_label(state.get("position")).into());
                        app.set_music_duration(time_label(state.get("duration")).into());
                    }
                    "notify_interaction_queue" => {
                        let queue = state
                            .as_array()
                            .or_else(|| state.get("queue").and_then(Value::as_array));
                        app.set_interaction_summary(
                            format!("{} queued interactions", queue.map_or(0, Vec::len)).into(),
                        );
                        if let Ok(guard) = store2.lock() {
                            app.set_dashboard_interactions(interaction_rows(&guard.interactions));
                        }
                    }
                    "notify_interaction" => {
                        if let Ok(guard) = store2.lock() {
                            app.set_dashboard_interactions(interaction_rows(&guard.interactions));
                        }
                    }
                    "notify_system_info" => app.set_system_summary(summary(&state).into()),
                    "notify_storage_update" => app.set_storage_summary(summary(&state).into()),
                    "notify_update_manager" => app.set_update_summary(summary(&state).into()),
                    "notify_speedtest_update" => app.set_speedtest_summary(summary(&state).into()),
                    "notify_macro_update"
                    | "notify_auto_macros_update"
                    | "notify_channel_point_update"
                    | "notify_audio_update" => {
                        if let Ok(guard) = store2.lock() {
                            // The on-screen data is replaced with the latest complete snapshot.
                            if method == "notify_macro_update" {
                                app.set_macros(slint::ModelRc::new(VecModel::from(
                                    guard
                                        .macros
                                        .iter()
                                        .map(|m| SharedString::from(m.as_str()))
                                        .collect::<Vec<_>>(),
                                )));
                                let configured =
                                    crate::config::dashboard::selected_names("macro_names");
                                app.set_dashboard_macro_list(slint::ModelRc::new(VecModel::from(
                                    configured
                                        .iter()
                                        .filter(|name| guard.macros.contains(name))
                                        .map(|name| SharedString::from(name.as_str()))
                                        .collect::<Vec<_>>(),
                                )));
                            }
                            if method == "notify_auto_macros_update" {
                                app.set_dashboard_auto_macros(auto_macro_rows(&guard.auto_macros));
                                app.set_auto_macros(slint::ModelRc::new(VecModel::from(
                                    guard
                                        .auto_macros
                                        .iter()
                                        .map(|m| {
                                            let label = string_field(m, &["name"]);
                                            let status =
                                                if m.get("enabled").and_then(Value::as_bool)
                                                    == Some(true)
                                                {
                                                    "ON"
                                                } else {
                                                    "OFF"
                                                };
                                            SharedString::from(format!("{label}  [{status}]"))
                                        })
                                        .collect::<Vec<_>>(),
                                )));
                            }
                            if method == "notify_channel_point_update" {
                                app.set_channel_points(slint::ModelRc::new(VecModel::from(
                                    guard
                                        .points
                                        .iter()
                                        .map(|m| {
                                            let label = string_field(
                                                m,
                                                &["label", "name", "twitch_label", "twitch_name"],
                                            );
                                            let status = if m.get("active").and_then(Value::as_bool)
                                                == Some(true)
                                            {
                                                "ON"
                                            } else {
                                                "OFF"
                                            };
                                            SharedString::from(format!("{label}  [{status}]"))
                                        })
                                        .collect::<Vec<_>>(),
                                )));
                            }
                            if method == "notify_audio_update" {
                                app.set_audio_interfaces(slint::ModelRc::new(VecModel::from(
                                    guard
                                        .audio
                                        .iter()
                                        .map(|a| SharedString::from(a.as_str()))
                                        .collect::<Vec<_>>(),
                                )));
                            }
                        }
                    }
                    _ => {}
                }
            });
        }
    });
}
