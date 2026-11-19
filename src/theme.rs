use crate::{ui_bridge::ui_event, App, Theme};
use slint::{Color, ComponentHandle};
use std::{path::PathBuf, process::Command, sync::Mutex};

fn apply(app: &App, palette: &serde_json::Value) {
    let theme = app.global::<Theme>();
    let color = |key: &str, fallback: u32| {
        let value = palette[key]
            .as_str()
            .and_then(|s| u32::from_str_radix(s.trim_start_matches('#'), 16).ok())
            .unwrap_or(fallback);
        Color::from_argb_encoded(0xff000000 | value)
    };
    theme.set_background(color("background", 0x111318));
    theme.set_surface(color("surface_container", 0x1d2024));
    theme.set_elevated(color("surface_container_high", 0x282a2f));
    theme.set_raised(color("surface_container_highest", 0x33353a));
    theme.set_primary(color("primary", 0xa8c7fa));
    theme.set_on_primary(color("on_primary", 0x062e6f));
    theme.set_text(color("on_surface", 0xe2e2e9));
    theme.set_muted(color("on_surface_variant", 0xc4c6d0));
}

pub(crate) fn wallpaper(app: &App, path: Option<PathBuf>) {
    static GENERATOR: Mutex<()> = Mutex::new(());
    let name = path
        .as_ref()
        .map(|p| p.to_string_lossy().into_owned())
        .unwrap_or_default();
    if app.get_theme_wallpaper().as_str() == name {
        return;
    }
    app.set_theme_wallpaper(name.as_str().into());
    apply(app, &serde_json::Value::Null);
    let Some(path) = path else { return };
    let weak = app.as_weak();
    std::thread::spawn(move || {
        let Ok(_guard) = GENERATOR.lock() else { return };
        let status = Command::new("/usr/lib/streambot-touch/generate-theme")
            .arg(path)
            .output();
        if !status.is_ok_and(|s| s.status.success()) {
            return;
        }
        let cache = std::env::var_os("XDG_CACHE_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| {
                PathBuf::from(std::env::var_os("HOME").unwrap_or_default()).join(".cache")
            });
        if let Some(palette) = std::fs::read(cache.join("streambot-touch/theme.json"))
            .ok()
            .and_then(|s| serde_json::from_slice(&s).ok())
        {
            ui_event(&weak, move |app| {
                if app.get_theme_wallpaper().as_str() == name {
                    apply(&app, &palette);
                }
            });
        }
    });
}
