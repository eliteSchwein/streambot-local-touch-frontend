//! Channel point rows for the controls page, including their reward images.
//!
//! Images are fetched once on a background thread, scaled down and cached; the
//! rows are rebuilt on the UI thread whenever an image finishes loading.
use crate::{state::presentation::string_field, ui_bridge::ui_event, App, ChannelPointRow};
use serde_json::Value;
use slint::{ComponentHandle, Model, ModelRc, Rgba8Pixel, SharedPixelBuffer, VecModel};
use std::{
    collections::{HashMap, HashSet},
    sync::{mpsc, Mutex, OnceLock},
    time::Duration,
};

/// Decoded thumbnails by URL; `None` marks an image that could not be loaded.
type Cache = HashMap<String, Option<SharedPixelBuffer<Rgba8Pixel>>>;

fn cache() -> &'static Mutex<Cache> {
    static CACHE: OnceLock<Mutex<Cache>> = OnceLock::new();
    CACHE.get_or_init(Default::default)
}

fn pending() -> &'static Mutex<HashSet<String>> {
    static PENDING: OnceLock<Mutex<HashSet<String>>> = OnceLock::new();
    PENDING.get_or_init(Default::default)
}

fn tint(value: &str) -> slint::Color {
    let hex = value.trim().trim_start_matches('#');
    match (hex.len(), u32::from_str_radix(hex, 16)) {
        (6, Ok(rgb)) => slint::Color::from_argb_encoded(0xff00_0000 | rgb),
        _ => slint::Color::default(),
    }
}

fn image_url(point: &Value) -> String {
    let url = string_field(point, &["image", "image_url", "imageUrl"]);
    if !url.is_empty() {
        return url;
    }
    // Twitch reward payloads nest the URLs.
    [
        "/image/url_4x",
        "/image/url_2x",
        "/default_image/url_4x",
        "/default_image/url_2x",
    ]
    .iter()
    .find_map(|path| point.pointer(path).and_then(Value::as_str))
    .unwrap_or("")
    .to_owned()
}

/// Builds the rows from the backend list and starts loading missing images.
pub(crate) fn update(app: &App, points: &[Value]) {
    let mut missing = Vec::new();
    let rows: Vec<ChannelPointRow> = {
        let cache = cache().lock().unwrap_or_else(|e| e.into_inner());
        let pending = pending().lock().unwrap_or_else(|e| e.into_inner());
        points
            .iter()
            .map(|point| {
                let label = string_field(point, &["label", "name", "twitch_label", "twitch_name"]);
                let subtitle = string_field(point, &["twitch_label", "twitch_name"]);
                let url = image_url(point);
                let cached = cache.get(&url);
                if !url.is_empty() && cached.is_none() && !pending.contains(&url) {
                    missing.push(url.clone());
                }
                ChannelPointRow {
                    id: point.to_string().into(),
                    subtitle: if subtitle == label {
                        String::new()
                    } else {
                        subtitle
                    }
                    .into(),
                    label: label.into(),
                    active: point["active"] == true,
                    image: cached
                        .and_then(Option::as_ref)
                        .map(|buffer| slint::Image::from_rgba8(buffer.clone()))
                        .unwrap_or_default(),
                    image_loading: !url.is_empty() && cached.is_none(),
                    image_url: url.into(),
                    tint: tint(&string_field(
                        point,
                        &["background", "background_color", "color"],
                    )),
                }
            })
            .collect()
    };
    app.set_channel_points(ModelRc::new(VecModel::from(rows)));
    if !missing.is_empty() {
        request(app, missing);
    }
}

/// Copies freshly loaded images into the current rows.
fn refresh(app: &App) {
    let current = app.get_channel_points();
    let cache = cache().lock().unwrap_or_else(|e| e.into_inner());
    let rows: Vec<ChannelPointRow> = current
        .iter()
        .map(|mut row| {
            if let Some(entry) = cache.get(row.image_url.as_str()) {
                row.image_loading = false;
                if let Some(buffer) = entry {
                    row.image = slint::Image::from_rgba8(buffer.clone());
                }
            }
            row
        })
        .collect();
    // A new model (rather than set_row_data) so the filtered view re-evaluates.
    app.set_channel_points(ModelRc::new(VecModel::from(rows)));
}

fn decode(bytes: &[u8]) -> Option<SharedPixelBuffer<Rgba8Pixel>> {
    let image = image::load_from_memory(bytes).ok()?;
    let rgba = image
        .resize(96, 96, image::imageops::FilterType::Triangle)
        .to_rgba8();
    Some(SharedPixelBuffer::clone_from_slice(
        rgba.as_raw(),
        rgba.width(),
        rgba.height(),
    ))
}

async fn load(client: &reqwest::Client, url: &str) -> Option<SharedPixelBuffer<Rgba8Pixel>> {
    if url.starts_with("http://") || url.starts_with("https://") {
        let response = client.get(url).send().await.ok()?.error_for_status().ok()?;
        decode(&response.bytes().await.ok()?)
    } else {
        decode(&std::fs::read(url.trim_start_matches("file://")).ok()?)
    }
}

fn request(app: &App, urls: Vec<String>) {
    struct Job {
        app: slint::Weak<App>,
        urls: Vec<String>,
    }
    static WORKER: OnceLock<mpsc::Sender<Job>> = OnceLock::new();
    pending()
        .lock()
        .unwrap_or_else(|e| e.into_inner())
        .extend(urls.iter().cloned());
    let worker = WORKER.get_or_init(|| {
        let (tx, rx) = mpsc::channel::<Job>();
        std::thread::spawn(move || {
            let Ok(runtime) = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
            else {
                return;
            };
            let Ok(client) = reqwest::Client::builder()
                .timeout(Duration::from_secs(10))
                .build()
            else {
                return;
            };
            while let Ok(job) = rx.recv() {
                for url in job.urls {
                    let image = runtime.block_on(load(&client, &url));
                    cache()
                        .lock()
                        .unwrap_or_else(|e| e.into_inner())
                        .insert(url.clone(), image);
                    pending()
                        .lock()
                        .unwrap_or_else(|e| e.into_inner())
                        .remove(&url);
                    ui_event(&job.app, |app| refresh(&app));
                }
            }
        });
        tx
    });
    let _ = worker.send(Job {
        app: app.as_weak(),
        urls,
    });
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn reads_image_url_and_tint_from_reward_payloads() {
        assert_eq!(
            image_url(&json!({"image": "https://a/1.png"})),
            "https://a/1.png"
        );
        assert_eq!(
            image_url(&json!({"image": null, "default_image": {"url_2x": "https://a/2.png"}})),
            "https://a/2.png"
        );
        assert_eq!(image_url(&json!({"name": "x"})), "");
        assert_eq!(tint("#9147FF"), slint::Color::from_rgb_u8(0x91, 0x47, 0xff));
        assert_eq!(tint("grey-darken-3"), slint::Color::default());
    }

    #[test]
    fn decodes_and_shrinks_images() {
        let mut png = Vec::new();
        image::RgbaImage::from_pixel(300, 150, image::Rgba([1, 2, 3, 255]))
            .write_to(&mut std::io::Cursor::new(&mut png), image::ImageFormat::Png)
            .unwrap();
        let buffer = decode(&png).unwrap();
        assert_eq!((buffer.width(), buffer.height()), (96, 48));
        assert!(decode(b"not an image").is_none());
    }
}
