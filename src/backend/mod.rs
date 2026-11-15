pub(crate) mod cava;

use crate::{
    config::Settings, state::presentation::string_field, state::store::Store, ui_bridge::ui_event,
    App,
};
use futures_util::{SinkExt, StreamExt};
use serde_json::{json, Value};
use std::{
    sync::{Arc, Mutex},
    time::Duration,
};
use tokio::{sync::mpsc, time};
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

pub(crate) async fn run(
    config: Settings,
    tx: mpsc::UnboundedSender<Value>,
    ui: slint::Weak<App>,
    store: Arc<Mutex<Store>>,
    mut command_rx: mpsc::UnboundedReceiver<(String, Value)>,
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
                app.set_backend_stage(stage.into());
            });
            time::sleep(Duration::from_millis(500)).await;
            continue;
        }
        ui_event(&ui, |app| app.set_connection("Connecting…".into()));
        match connect_async(config.ws_url()).await {
            Ok((ws, _)) => {
                if let Ok(mut guard) = store.lock() {
                    guard.reset();
                }
                ui_event(&ui, |app| app.set_connection("Connected".into()));
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
                loop {
                    tokio::select! {
                        command = command_rx.recv() => {
                            if let Some((method, params)) = command {
                                let message = json!({"jsonrpc":"2.0", "id":next_id, "method":method, "params":params});
                                next_id += 1;
                                if sink.send(Message::Text(message.to_string().into())).await.is_err() { break; }
                            }
                        }
                        packet = stream.next() => {
                            match packet {
                                Some(Ok(Message::Text(text))) => {
                                    if let Ok(value) = serde_json::from_str::<Value>(&text) {
                                        let _ = tx.send(value);
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
        if let Ok(mut guard) = store.lock() {
            guard.reset();
        }
        ui_event(&ui, |app| {
            app.set_connection("Disconnected — retrying".into())
        });
        time::sleep(Duration::from_secs(2)).await;
    }
}
