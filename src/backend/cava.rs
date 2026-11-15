use crate::{config::Settings, ui_bridge::ui_event, App};
use futures_util::StreamExt;
use serde_json::Value;
use slint::VecModel;
use std::time::Duration;
use tokio::time;
use tokio_tungstenite::{connect_async, tungstenite::Message};

pub(crate) async fn cava_client(config: Settings, ui: slint::Weak<App>) {
    let mut bars = [0.0_f32; 5];
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
                let values: Vec<f32> = raw
                    .lines()
                    .find_map(|line| {
                        let numbers: Vec<f32> = line
                            .split(|c: char| c == ';' || c == ',' || c.is_whitespace())
                            .filter_map(|token| token.parse().ok())
                            .collect();
                        if numbers.is_empty() {
                            None
                        } else {
                            let mut numbers = numbers;
                            if numbers.len() > 1 {
                                numbers.pop();
                            }
                            Some(numbers)
                        }
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
                let frame = bars;
                ui_event(&ui, move |app| {
                    app.set_cava_bars(slint::ModelRc::new(VecModel::from(frame.to_vec())));
                });
            }
        }
        time::sleep(Duration::from_secs(2)).await;
    }
}
