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

/// Last applied wallpaper and its matugen palette, kept in
/// `~/.local/share/streambot/touch/` so startup can show both immediately.
mod cache {
    use serde_json::{json, Value};
    use slint::{Rgb8Pixel, SharedPixelBuffer};
    use std::{
        fs, io,
        path::{Path, PathBuf},
        time::UNIX_EPOCH,
    };

    const IMAGE: &str = "wallpaper.jpg";
    const THEME: &str = "theme.json";
    const STATE: &str = "state.json";

    pub(super) fn directory() -> PathBuf {
        std::env::var_os("XDG_DATA_HOME")
            .map(PathBuf::from)
            .filter(|path| path.is_absolute())
            .unwrap_or_else(|| {
                PathBuf::from(std::env::var_os("HOME").unwrap_or_default()).join(".local/share")
            })
            .join("streambot/touch")
    }

    /// Identifies the source file, so an edited or replaced image invalidates the cache.
    fn stamp(source: &Path) -> Value {
        let meta = fs::metadata(source).ok();
        let modified = meta
            .as_ref()
            .and_then(|meta| meta.modified().ok())
            .and_then(|time| time.duration_since(UNIX_EPOCH).ok())
            .map(|time| time.as_millis() as u64);
        json!({"modified": modified, "size": meta.map(|meta| meta.len())})
    }

    fn write_atomic(path: &Path, bytes: &[u8]) -> io::Result<()> {
        let temporary = path.with_extension("tmp");
        fs::write(&temporary, bytes)?;
        fs::rename(temporary, path)
    }

    pub(super) fn store(
        dir: &Path,
        name: &str,
        source: &Path,
        image: &SharedPixelBuffer<Rgb8Pixel>,
        palette: Option<&Value>,
    ) -> Result<(), Box<dyn std::error::Error>> {
        fs::create_dir_all(dir)?;
        // Invalidate first so a crash mid-write never pairs old files with a new name.
        let _ = fs::remove_file(dir.join(STATE));
        let mut jpeg = Vec::new();
        image::codecs::jpeg::JpegEncoder::new_with_quality(&mut jpeg, 90).encode(
            image.as_bytes(),
            image.width(),
            image.height(),
            image::ExtendedColorType::Rgb8,
        )?;
        write_atomic(&dir.join(IMAGE), &jpeg)?;
        match palette {
            Some(palette) => write_atomic(&dir.join(THEME), &serde_json::to_vec_pretty(palette)?)?,
            None => {
                let _ = fs::remove_file(dir.join(THEME));
            }
        }
        let state = json!({"wallpaper": name, "source": stamp(source)});
        write_atomic(&dir.join(STATE), &serde_json::to_vec_pretty(&state)?)?;
        Ok(())
    }

    pub(super) fn clear(dir: &Path) {
        for file in [STATE, IMAGE, THEME] {
            let _ = fs::remove_file(dir.join(file));
        }
    }

    pub(super) struct Cached {
        pub(super) image: SharedPixelBuffer<Rgb8Pixel>,
        pub(super) palette: Option<Value>,
    }

    /// The cached wallpaper, if it was made from `name` and the source is unchanged.
    pub(super) fn load(dir: &Path, name: &str, source: &Path) -> Option<Cached> {
        let state: Value = serde_json::from_slice(&fs::read(dir.join(STATE)).ok()?).ok()?;
        if state["wallpaper"].as_str() != Some(name) || state["source"] != stamp(source) {
            return None;
        }
        let rgb = image::load_from_memory(&fs::read(dir.join(IMAGE)).ok()?)
            .ok()?
            .to_rgb8();
        let palette = fs::read(dir.join(THEME))
            .ok()
            .and_then(|bytes| serde_json::from_slice(&bytes).ok());
        Some(Cached {
            image: SharedPixelBuffer::clone_from_slice(rgb.as_raw(), rgb.width(), rgb.height()),
            palette,
        })
    }
}

/// Startup: apply the cached wallpaper and theme instantly when they still match,
/// otherwise load (and cache) the wallpaper in the background.
pub(crate) fn restore(app: &App, name: &str) {
    let cached = dashboard::wallpaper_path(name)
        .and_then(|source| cache::load(&cache::directory(), name, &source));
    match cached {
        Some(cached) => {
            theme::apply(
                app,
                cached.palette.as_ref().unwrap_or(&serde_json::Value::Null),
            );
            app.set_wallpaper_image(slint::Image::from_rgb8(cached.image));
            app.set_theme_wallpaper(name.into());
        }
        None => set(app, name),
    }
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
        cache::clear(&cache::directory());
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
                // The kiosk panel is at most 1280×800; larger decodes only cost memory.
                let image = path.as_deref().and_then(|path| decode(path, 1280, 800));
                let name = request.name.clone();
                let shown = image.clone();
                ui_event(&request.app, move |app| {
                    if app.get_theme_wallpaper().as_str() == name {
                        app.set_wallpaper_image(
                            shown.map(slint::Image::from_rgb8).unwrap_or_default(),
                        );
                    }
                });
                let palette = path.as_deref().map(theme::generate).transpose();
                if let (Some(source), Some(image)) = (path.as_deref(), image.as_ref()) {
                    let colors = palette.as_ref().ok().and_then(Option::as_ref);
                    if let Err(error) =
                        cache::store(&cache::directory(), &request.name, source, image, colors)
                    {
                        eprintln!("Wallpaper cache: {error}");
                    }
                }
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
                            loading: index > 0,
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
                    if thumbnails.len() >= 48 && !thumbnails.contains_key(&key) {
                        thumbnails.clear();
                    }
                    // `None` (undecodable file) still clears the tile's spinner.
                    let thumbnail = thumbnails
                        .entry(key.clone())
                        .or_insert_with(|| decode(&key.0, 360, 224))
                        .clone();
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
                            if let Some(thumbnail) = thumbnail {
                                row.thumbnail = slint::Image::from_rgb8(thumbnail);
                            }
                            row.loading = false;
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

#[cfg(test)]
mod tests {
    use super::cache;
    use serde_json::json;
    use slint::{Rgb8Pixel, SharedPixelBuffer};

    #[test]
    fn cache_round_trips_and_follows_the_source_file() {
        let root = std::env::temp_dir().join(format!("streambot-cache-{}", std::process::id()));
        let dir = root.join("touch");
        let source = root.join("wall.png");
        std::fs::create_dir_all(&root).unwrap();
        std::fs::write(&source, b"original").unwrap();
        let mut image = SharedPixelBuffer::<Rgb8Pixel>::new(32, 18);
        image.make_mut_slice().fill(Rgb8Pixel {
            r: 200,
            g: 40,
            b: 40,
        });
        let palette = json!({"primary": "#f0a000"});

        cache::store(&dir, "wall.png", &source, &image, Some(&palette)).unwrap();
        let cached = cache::load(&dir, "wall.png", &source).expect("cache hit");
        assert_eq!((cached.image.width(), cached.image.height()), (32, 18));
        assert_eq!(cached.palette, Some(palette));
        assert!(
            cache::load(&dir, "other.png", &source).is_none(),
            "different wallpaper"
        );

        std::fs::write(&source, b"replaced with new bytes").unwrap();
        assert!(
            cache::load(&dir, "wall.png", &source).is_none(),
            "source changed"
        );

        cache::clear(&dir);
        assert!(cache::load(&dir, "wall.png", &source).is_none());
        let _ = std::fs::remove_dir_all(root);
    }
}
