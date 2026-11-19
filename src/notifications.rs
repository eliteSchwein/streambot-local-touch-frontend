use crate::{
    state::{
        models::{auto_macro_rows, interaction_rows},
        presentation::{self, string_field, time_label},
        store::Store,
    },
    App,
};
use serde_json::Value;
use slint::{Model, SharedString, VecModel};
pub(crate) fn apply(app: &App, guard: &mut Store, method: &str, params: &Value) {
    let state = guard.accept(method, params);
    match method {
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
            app.set_music_playing(state.get("status").and_then(Value::as_str) == Some("playing"));
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
            app.set_dashboard_interactions(interaction_rows(&guard.interactions));
        }
        "notify_interaction" => {
            app.set_dashboard_interactions(interaction_rows(&guard.interactions));
        }
        "notify_system_info" => app.set_system_summary(presentation::system(&state).into()),
        "notify_storage_update" => app.set_storage_summary(presentation::storage(&state).into()),
        "notify_update_manager" => {
            app.set_updates(presentation::updates(&state));
            app.invoke_advance_updates();
        }
        "notify_speedtest_update" => {
            app.set_speedtest_running(state["running"] == true);
            app.set_speedtest_summary(presentation::speedtest(&state).into());
        }
        "notify_audio_update" | "notify_audio_outputs_update" => {
            let rows = crate::audio::rows(&guard.audio, &guard.outputs);
            if app.get_page() != 1 {
                let before = app.get_audio_interfaces();
                for item in rows.iter() {
                    if before.iter().any(|old| {
                        old.id == item.id
                            && old.physical == item.physical
                            && ((old.volume - item.volume).abs() > 0.0005
                                || old.muted != item.muted)
                    }) {
                        app.set_osd_item(item);
                        app.set_osd_visible(true);
                        let weak = slint::ComponentHandle::as_weak(app);
                        let revision = app.get_osd_revision().wrapping_add(1);
                        app.set_osd_revision(revision);
                        slint::Timer::single_shot(std::time::Duration::from_secs(3), move || {
                            if let Some(app) = weak
                                .upgrade()
                                .filter(|app| app.get_osd_revision() == revision)
                            {
                                app.set_osd_visible(false);
                            }
                        });
                        break;
                    }
                }
            }
            app.set_audio_interfaces(rows);
        }
        "notify_settings_update" => {
            let settings = state.get("system_config").unwrap_or(&state);
            if let Some(lang @ ("en" | "de")) = settings["language"].as_str() {
                app.set_language(lang.into());
            }
            if let Some(wallpaper) = settings["touch_wallpaper"].as_str() {
                crate::dashboard_editor::set_wallpaper_image(app, wallpaper);
            }
        }
        "notify_macro_update" => {
            app.set_macros(slint::ModelRc::new(VecModel::from(
                guard
                    .macros
                    .iter()
                    .map(|m| SharedString::from(m.as_str()))
                    .collect::<Vec<_>>(),
            )));
            let configured = crate::config::dashboard::selected_names("macro_names");
            app.set_dashboard_macro_list(slint::ModelRc::new(VecModel::from(
                configured
                    .iter()
                    .filter(|name| guard.macros.contains(name))
                    .map(|name| SharedString::from(name.as_str()))
                    .collect::<Vec<_>>(),
            )));
        }
        "notify_auto_macros_update" => {
            app.set_dashboard_auto_macros(auto_macro_rows(&guard.auto_macros));
            app.set_auto_macros(slint::ModelRc::new(VecModel::from(
                guard
                    .auto_macros
                    .iter()
                    .map(|m| {
                        let label = string_field(m, &["name"]);
                        crate::ActionRow {
                            id: label.as_str().into(),
                            label: label.into(),
                            active: m["enabled"] == true,
                        }
                    })
                    .collect::<Vec<_>>(),
            )));
        }
        "notify_channel_point_update" => {
            app.set_channel_points(slint::ModelRc::new(VecModel::from(
                guard
                    .points
                    .iter()
                    .map(|m| {
                        let label =
                            string_field(m, &["label", "name", "twitch_label", "twitch_name"]);
                        crate::ActionRow {
                            id: m.to_string().into(),
                            label: label.into(),
                            active: m["active"] == true,
                        }
                    })
                    .collect::<Vec<_>>(),
            )));
        }
        _ => {}
    }
}
