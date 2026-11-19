use crate::{config::Settings, ui_bridge::ui_event, App};
use futures_util::StreamExt;
use serde_json::Value;
use slint::{Model, VecModel};
use std::time::{Duration, Instant};
use tokio::time;
use tokio_tungstenite::{connect_async, tungstenite::Message};

const FRAME_INTERVAL: Duration = Duration::from_millis(16);

pub(crate) async fn cava_client(config: Settings, ui: slint::Weak<App>) {
    let mut bars = [0.0_f32; 5];
    let mut last_push = Instant::now() - FRAME_INTERVAL;
    loop {
        let url = format!("{}/cava/music_preview", config.ws_url());
        if let Ok((socket, _)) = connect_async(url).await {
            let (_, mut incoming) = socket.split();
            while let Some(Ok(packet)) = incoming.next().await {
                let Message::Text(text) = packet else {
                    continue;
                };
                let Ok(value) = serde_json::from_str::<Value>(&text) else {
                    continue;
                };
                if value.pointer("/params/target").and_then(Value::as_str) != Some("music_preview")
                {
                    continue;
                }
                let Some(raw) = value.pointer("/params/raw").and_then(Value::as_str) else {
                    continue;
                };
                // A packet can carry several frames; the last complete one is the newest.
                let values: Vec<f32> = raw
                    .lines()
                    .rev()
                    .find_map(|line| {
                        let mut numbers: Vec<f32> = line
                            .split(|c: char| c == ';' || c == ',' || c.is_whitespace())
                            .filter_map(|token| token.parse().ok())
                            .collect();
                        // Drop a trailing extra value only when there are more than we draw.
                        if numbers.len() > bars.len() {
                            numbers.truncate(bars.len());
                        }
                        (!numbers.is_empty()).then_some(numbers)
                    })
                    .unwrap_or_default();
                if values.is_empty() {
                    continue;
                }
                for (i, bar) in bars.iter_mut().enumerate() {
                    let target = values.get(i).copied().unwrap_or(0.0).clamp(0.0, 100.0);
                    *bar = if target > *bar {
                        *bar + (target - *bar) * 0.45
                    } else {
                        (*bar - 6.0).max(target)
                    };
                }
                // Cap UI updates to ~60 fps so bursts don't flood the event loop.
                let now = Instant::now();
                if now.duration_since(last_push) < FRAME_INTERVAL {
                    continue;
                }
                last_push = now;
                let frame = bars;
                ui_event(&ui, move |app| push_bars(&app, &frame));
            }
        }
        time::sleep(Duration::from_secs(2)).await;
    }
}

/// Updates the bars in place. Replacing the model would make Slint rebuild the
/// bar elements every frame, restarting their height animations (flicker).
fn push_bars(app: &App, frame: &[f32]) {
    let current = app.get_cava_bars();
    if let Some(model) = current.as_any().downcast_ref::<VecModel<f32>>() {
        if model.row_count() == frame.len() {
            for (i, value) in frame.iter().enumerate() {
                if model.row_data(i) != Some(*value) {
                    model.set_row_data(i, *value);
                }
            }
            return;
        }
    }
    app.set_cava_bars(slint::ModelRc::new(VecModel::from(frame.to_vec())));
}
