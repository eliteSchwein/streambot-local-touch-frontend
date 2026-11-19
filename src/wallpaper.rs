use crate::{config::dashboard, theme, ui_bridge::ui_event, App, PickerEntry};
use slint::{ComponentHandle, Model, ModelRc, Rgb8Pixel, SharedPixelBuffer, VecModel};
use std::{
    path::Path,
    sync::{
        atomic::{AtomicU64, Ordering},
        mpsc, Arc, OnceLock,
    },
};

fn decode(path: &Path, width: u32, height: u32) -> Option<SharedPixelBuffer<Rgb8Pixel>> {
    let decoded = image::ImageReader::open(path).ok()?.decode().ok()?;
    let rgb = decoded
        .resize(width, height, image::imageops::FilterType::Triangle)
        .to_rgb8();
    Some(SharedPixelBuffer::clone_from_slice(
        rgb.as_raw(),
        rgb.width(),
        rgb.height(),
    ))
}

pub(crate) fn set(app: &App, name: &str) {
    struct Request {
        app: slint::Weak<App>,
        name: String,
    }
    static WORKER: OnceLock<mpsc::Sender<Request>> = OnceLock::new();
    if app.get_theme_wallpaper().as_str() == name {
        return;
    }
    app.set_theme_wallpaper(name.into());
    if name.is_empty() {
        app.set_wallpaper_image(slint::Image::default());
        theme::apply(app, &serde_json::Value::Null);
    }
    let worker = WORKER.get_or_init(|| {
        let (tx, rx) = mpsc::channel::<Request>();
        std::thread::spawn(move || {
            while let Ok(first) = rx.recv() {
                // Skip requests superseded while an image was being processed.
                let request = rx.try_iter().last().unwrap_or(first);
                if request.name.is_empty() {
                    continue;
                }
                let path = dashboard::wallpaper_path(&request.name);
                let image = path.as_deref().and_then(|path| decode(path, 1920, 1080));
                let name = request.name.clone();
                ui_event(&request.app, move |app| {
                    if app.get_theme_wallpaper().as_str() == name {
                        app.set_wallpaper_image(
                            image.map(slint::Image::from_rgb8).unwrap_or_default(),
                        );
                    }
                });
                let palette = path.as_deref().map(theme::generate).transpose();
                ui_event(&request.app, move |app| {
                    if app.get_theme_wallpaper().as_str() == request.name {
                        match palette {
                            Ok(Some(palette)) => theme::apply(&app, &palette),
                            Ok(None) => theme::apply(&app, &serde_json::Value::Null),
                            Err(error) => {
                                theme::apply(&app, &serde_json::Value::Null);
                                eprintln!("Matugen: {error}");
                                if app.get_dashboard_editing() {
                                    let label = crate::i18n::text(
                                        &app.get_language(),
                                        "dashboard_wallpaper_palette_error",
                                    );
                                    app.set_feedback(format!("{label}: {error}").into());
                                }
                            }
                        }
                    }
                });
            }
        });
        tx
    });
    let _ = worker.send(Request {
        app: app.as_weak(),
        name: name.into(),
    });
}

#[derive(Clone)]
pub(crate) struct Picker {
    generation: Arc<AtomicU64>,
    requests: mpsc::Sender<(slint::Weak<App>, u64, String)>,
}

impl Picker {
    pub(crate) fn new() -> Self {
        let generation = Arc::new(AtomicU64::new(0));
        let current = generation.clone();
        let (requests, input) = mpsc::channel::<(slint::Weak<App>, u64, String)>();
        std::thread::spawn(move || {
            let mut thumbnails = std::collections::HashMap::new();
            while let Ok((app, request, selected)) = input.recv() {
                if current.load(Ordering::Relaxed) != request {
                    continue;
                }
                let names =
                    dashboard::wallpaper_files(|| current.load(Ordering::Relaxed) == request);
                if current.load(Ordering::Relaxed) != request {
                    continue;
                }
                let display_names = names.clone();
                let epoch = current.clone();
                ui_event(&app, move |app| {
                    if epoch.load(Ordering::Relaxed) != request {
                        return;
                    }
                    let entries = std::iter::once(String::new())
                        .chain(display_names)
                        .enumerate()
                        .map(|(index, name)| PickerEntry {
                            selected: (index == 0 && selected.is_empty()) || name == selected,
                            name: name.into(),
                            thumbnail: slint::Image::default(),
                        })
                        .collect::<Vec<_>>();
                    app.set_dashboard_picker_items(ModelRc::new(VecModel::from(entries)));
                    app.set_wallpaper_picker_loading(false);
                });
                for (index, name) in names.into_iter().enumerate() {
                    if current.load(Ordering::Relaxed) != request {
                        break;
                    }
                    let Some(path) = dashboard::wallpaper_path(&name) else {
                        continue;
                    };
                    let modified = path.metadata().ok().and_then(|meta| meta.modified().ok());
                    let key = (path, modified);
                    if thumbnails.len() >= 128 && !thumbnails.contains_key(&key) {
                        thumbnails.clear();
                    }
                    let Some(thumbnail) = thumbnails
                        .entry(key.clone())
                        .or_insert_with(|| decode(&key.0, 160, 96))
                        .clone()
                    else {
                        continue;
                    };
                    let epoch = current.clone();
                    ui_event(&app, move |app| {
                        if epoch.load(Ordering::Relaxed) != request {
                            return;
                        }
                        let model = app.get_dashboard_picker_items();
                        let Some(rows) = model.as_any().downcast_ref::<VecModel<PickerEntry>>()
                        else {
                            return;
                        };
                        if let Some(mut row) = rows.row_data(index + 1) {
                            row.thumbnail = slint::Image::from_rgb8(thumbnail);
                            rows.set_row_data(index + 1, row);
                        }
                    });
                }
            }
        });
        Self {
            generation,
            requests,
        }
    }

    pub(crate) fn open(&self, app: &App, selected: &str) {
        self.cancel();
        app.set_dashboard_picker_items(ModelRc::new(VecModel::default()));
        app.set_wallpaper_picker_loading(true);
        let request = self.generation.load(Ordering::Relaxed);
        let _ = self
            .requests
            .send((app.as_weak(), request, selected.into()));
    }

    pub(crate) fn cancel(&self) {
        self.generation.fetch_add(1, Ordering::Relaxed);
    }
}
