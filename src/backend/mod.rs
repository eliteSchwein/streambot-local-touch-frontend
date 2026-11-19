pub(crate) mod cava;

use crate::{
    config::Settings, state::presentation::string_field, state::store::Store, ui_bridge::ui_event,
    App,
};
use futures_util::{SinkExt, StreamExt};
use serde_json::{json, Value};
use std::{
    collections::HashMap,
    sync::{Arc, Mutex},
    time::Duration,
};
use tokio::{
    sync::{mpsc, watch},
    time,
};
use tokio_tungstenite::{connect_async, tungstenite::Message};

pub(crate) const ENDPOINTS: &[&str] = &[
    "notify_interaction",
    "notify_interaction_queue",
    "notify_music_update",
    "notify_playlist_update",
    "notify_audio_update",
    "notify_audio_outputs_update",
    "notify_auto_macros_update",
    "notify_macro_update",
    "notify_channel_point_update",
    "notify_update_manager",
    "notify_storage_update",
    "notify_system_info",
    "notify_settings_update",
    "notify_speedtest_update",
];

struct PendingRequest {
    method: String,
    sent: time::Instant,
    macro_run: Option<(String, i32)>,
}
type Pending = HashMap<u64, PendingRequest>;

fn handle_packet(
    packet: Value,
    pending: &mut Pending,
    ui: &slint::Weak<App>,
    store: &Arc<Mutex<Store>>,
) {
    let method = packet["method"].as_str().unwrap_or("");
    let (endpoint, params) = if method.starts_with("notify_") {
        (method.to_owned(), packet["params"].clone())
    } else {
        let Some(id) = packet["id"].as_u64() else {
            return;
        };
        let Some(entry) = pending.get(&id) else {
            return;
        };
        if !method.is_empty() && method != format!("result_{}", entry.method) {
            return;
        }
        let PendingRequest {
            method: request,
            macro_run,
            ..
        } = pending.remove(&id).unwrap();
        if let Some((name, ticket)) = macro_run {
            let body = ["result", "params", "data", "payload"]
                .iter()
                .find_map(|key| packet.get(*key));
            let success = packet.get("error").is_none_or(Value::is_null)
                && !body.is_some_and(|body| body["success"] == false);
            ui_event(ui, move |app| {
                crate::ui_handlers::complete_macro(&app, name.into(), ticket, success)
            });
        }
        if let Some(error) = packet.get("error").filter(|e| !e.is_null()) {
            let detail = error["message"]
                .as_str()
                .map(str::to_owned)
                .unwrap_or_else(|| error.to_string());
            ui_event(ui, move |app| {
                app.set_feedback(format!("{request}: {detail}").into());
                if request == "update" {
                    app.invoke_cancel_updates();
                }
                if request == "speedtest" {
                    app.set_speedtest_starting(false);
                    app.set_speedtest_error(detail.into());
                }
            });
            return;
        }
        if request != "speedtest" {
            return;
        }
        let Some(body) = ["result", "params", "data"]
            .iter()
            .find_map(|key| packet.get(*key))
        else {
            return;
        };
        (
            "notify_speedtest_update".into(),
            body.get("speedtest").unwrap_or(body).clone(),
        )
    };
    let store = store.clone();
    ui_event(ui, move |app| {
        if let Ok(mut state) = store.lock() {
            crate::notifications::apply(&app, &mut state, &endpoint, &params);
        }
    });
}

pub(crate) async fn run(
    config: Settings,
    ui: slint::Weak<App>,
    store: Arc<Mutex<Store>>,
    mut command_rx: mpsc::UnboundedReceiver<(String, Value)>,
    music_visible: watch::Receiver<bool>,
) {
    let client = match reqwest::Client::builder()
        .timeout(Duration::from_secs(2))
        .build()
    {
        Ok(client) => client,
        Err(e) => {
            ui_event(&ui, move |app| {
                app.set_feedback(format!("HTTP client: {e}").into())
            });
            return;
        }
    };
    let mut next_id: u64 = 1;
    loop {
        let status = client.get(config.http_url()).send().await;
        let status = match status {
            Ok(resp) => resp.json::<Value>().await.ok(),
            Err(_) => None,
        };
        let inner = status.as_ref().map(|s| s.get("data").unwrap_or(s));
        let ready = inner
            .and_then(|s| s.get("ready"))
            .and_then(Value::as_bool)
            .unwrap_or(false);
        let stage = inner
            .map(|s| string_field(s, &["bootup_stage"]))
            .unwrap_or_default();
        if !ready {
            ui_event(&ui, move |app| {
                app.set_connection("Backend not ready".into());
                if status.is_some() {
                    app.set_backend_ready(false);
                    app.set_backend_stage(stage.into());
                }
            });
            time::sleep(Duration::from_millis(500)).await;
            continue;
        }
        ui_event(&ui, |app| {
            app.set_backend_ready(true);
            app.set_connection("Connecting…".into());
        });
        match connect_async(config.ws_url()).await {
            Ok((ws, _)) => {
                // Button presses from a closed connection must never be replayed.
                while command_rx.try_recv().is_ok() {}
                let mut pending = Pending::new();
                let (mut sink, mut stream) = ws.split();
                let register = json!({"jsonrpc":"2.0", "id":next_id, "method":"register_endpoints", "params":ENDPOINTS});
                next_id += 1;
                if sink
                    .send(Message::Text(register.to_string().into()))
                    .await
                    .is_err()
                {
                    continue;
                }
                let speed_id = next_id;
                next_id += 1;
                let status = json!({"jsonrpc":"2.0","id":speed_id,"method":"speedtest","params":{"action":"status"}});
                if sink.send(Message::text(status.to_string())).await.is_err() {
                    continue;
                }
                pending.insert(
                    speed_id,
                    PendingRequest {
                        method: "speedtest".into(),
                        sent: time::Instant::now(),
                        macro_run: None,
                    },
                );
                ui_event(&ui, |app| app.set_connection("Connected".into()));
                let cava = cava::cava_client(config.clone(), ui.clone(), music_visible.clone());
                tokio::pin!(cava);
                loop {
                    tokio::select! {
                        _ = &mut cava => break,
                        command = command_rx.recv() => {
                            let Some((method, mut params)) = command else { return };
                            let macro_run = if method == "trigger_macro" {
                                params.as_object_mut().and_then(|params| {
                                    let name = params.get("macro")?.as_str()?.to_owned();
                                    let ticket = params.remove("_kiosk_ticket")?.as_i64()? as i32;
                                    Some((name, ticket))
                                })
                            } else { None };
                            pending.retain(|_, request| request.sent.elapsed() < Duration::from_secs(60));
                            pending.insert(next_id, PendingRequest { method: method.clone(), sent: time::Instant::now(), macro_run });
                            let message = json!({"jsonrpc":"2.0", "id":next_id, "method":method, "params":params});
                            next_id += 1;
                            if sink.send(Message::Text(message.to_string().into())).await.is_err() { break; }
                        }
                        packet = stream.next() => {
                            match packet {
                                Some(Ok(Message::Text(text))) => {
                                    if let Ok(value) = serde_json::from_str::<Value>(&text) {
                                        handle_packet(value, &mut pending, &ui, &store);
                                    }
                                }
                                Some(Ok(Message::Ping(payload))) => { if sink.send(Message::Pong(payload)).await.is_err() { break; } }
                                Some(Ok(Message::Close(_))) | None | Some(Err(_)) => break,
                                _ => {}
                            }
                        }
                    }
                }
            }
            Err(e) => {
                let msg = format!("WebSocket: {e}");
                ui_event(&ui, move |app| app.set_feedback(msg.into()));
            }
        }
        let disconnected_store = store.clone();
        ui_event(&ui, move |app| {
            app.set_connection("Disconnected — retrying".into());
            app.invoke_cancel_updates();
            app.set_osd_visible(false);
            if let Ok(mut state) = disconnected_store.lock() {
                state.reset();
                for method in ENDPOINTS.iter().filter(|m| **m != "notify_settings_update") {
                    crate::notifications::apply(&app, &mut state, method, &Value::Null);
                }
            }
        });
        time::sleep(Duration::from_secs(2)).await;
    }
}
