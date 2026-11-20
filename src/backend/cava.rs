use crate::{config::Settings, ui_bridge::ui_event, App};
use futures_util::{SinkExt, StreamExt};
use serde_json::Value;
use slint::{Model, VecModel};
use std::time::{Duration, Instant};
use tokio::{sync::watch, time};
use tokio_tungstenite::{connect_async, tungstenite::Message};

const FRAME_INTERVAL: Duration = Duration::from_millis(16);

/// Streams visualizer levels while a music card is visible; the socket is
/// closed whenever no music card is on screen.
pub(crate) async fn cava_client(
    config: Settings,
    ui: slint::Weak<App>,
    mut visible: watch::Receiver<bool>,
) {
    let mut bars = [0.0_f32; 5];
    let mut last_push = Instant::now() - FRAME_INTERVAL;
    loop {
        if visible.wait_for(|shown| *shown).await.is_err() {
            return;
        }
        let url = format!("{}/cava/music_preview", config.ws_url());
        let Ok((socket, _)) = connect_async(url).await else {
            time::sleep(Duration::from_secs(2)).await;
            continue;
        };
        let (mut sink, mut incoming) = socket.split();
        loop {
            tokio::select! {
                changed = visible.changed() => {
                    if changed.is_err() || !*visible.borrow() {
                        let _ = sink.send(Message::Close(None)).await;
                        bars = [0.0; 5];
                        let frame = bars;
                        ui_event(&ui, move |app| push_bars(&app, &frame));
                        break;
                    }
                }
                packet = incoming.next() => {
                    let text = match packet {
                        Some(Ok(Message::Text(text))) => text,
                        Some(Ok(Message::Ping(payload))) => {
                            if sink.send(Message::Pong(payload)).await.is_err() { break; }
                            continue;
                        }
                        Some(Ok(_)) => continue,
                        Some(Err(_)) | None => {
                            time::sleep(Duration::from_secs(2)).await;
                            break;
                        }
                    };
                    let Some(values) = parse(&text, bars.len()) else { continue };
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
        }
    }
}

/// Extracts the newest frame of bar levels from a cava packet.
fn parse(text: &str, count: usize) -> Option<Vec<f32>> {
    let value = serde_json::from_str::<Value>(text).ok()?;
    if value.pointer("/params/target").and_then(Value::as_str) != Some("music_preview") {
        return None;
    }
    let raw = value.pointer("/params/raw").and_then(Value::as_str)?;
    // A packet can carry several frames; the last complete one is the newest.
    raw.lines().rev().find_map(|line| {
        let mut numbers: Vec<f32> = line
            .split(|c: char| c == ';' || c == ',' || c.is_whitespace())
            .filter_map(|token| token.parse().ok())
            .collect();
        // Drop trailing extra values only when there are more than we draw.
        numbers.truncate(count);
        (!numbers.is_empty()).then_some(numbers)
    })
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

#[cfg(test)]
mod tests {
    use super::parse;

    #[test]
    fn takes_the_newest_frame_and_ignores_other_targets() {
        let packet =
            r#"{"params":{"target":"music_preview","raw":"1;2;3;4;5;\n10;20;30;40;50;60;\n"}}"#;
        assert_eq!(parse(packet, 5), Some(vec![10.0, 20.0, 30.0, 40.0, 50.0]));
        let other = r#"{"params":{"target":"overlay","raw":"1;2;3;"}}"#;
        assert_eq!(parse(other, 5), None);
        assert_eq!(parse("not json", 5), None);
    }
}
