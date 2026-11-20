//! Streambot Touch: native Rust/Slint application entry point.
//! All view/model mutations are dispatched to Slint's event loop.

mod audio;
mod backend;
mod bluetooth;
mod channel_points;
mod config;
mod dashboard_editor;
mod diagnostics;
mod drawer;
mod i18n;
#[cfg(test)]
mod native_ui_test;
mod network;
mod notifications;
mod power;
mod state;
mod theme;
mod ui_bridge;
mod ui_handlers;
mod wallpaper;

use crate::{config::Settings, state::store::Store};
use serde_json::Value;
use slint::ComponentHandle;
use std::{
    sync::{Arc, Mutex},
    time::Duration,
};
use tokio::sync::{mpsc, watch};

slint::include_modules!();

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let config = Settings::load();
    let ui = App::new()?;
    let settings_path = config::settings_path();
    diagnostics::set_enabled(&ui, config::touch_dev_page(&settings_path));
    let store = Arc::new(Mutex::new(Store::default()));
    dashboard_editor::install(&ui, store.clone());
    let _drawer_refresh = drawer::install(&ui, config.rest_port);
    let weak = ui.as_weak();
    let (command_tx, command_rx) = mpsc::unbounded_channel::<(String, Value)>();
    let rt = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()?;

    ui_handlers::install(&ui, command_tx);
    power::install(&ui, rt.handle());

    let (music_visible_tx, music_visible) = watch::channel(ui.get_music_visible());
    ui.on_music_visible_changed(move |visible| {
        let _ = music_visible_tx.send(visible);
    });
    rt.spawn(backend::run(config, weak, store, command_rx, music_visible));
    #[cfg(unix)]
    {
        use tokio::signal::unix::{signal, SignalKind};
        let _guard = rt.enter();
        let mut power_key = signal(SignalKind::user_defined1())?;
        let window = ui.as_weak();
        rt.spawn(async move {
            while power_key.recv().await.is_some() {
                ui_bridge::ui_event(&window, |app| app.set_power_menu_open(true));
            }
        });
    }
    diagnostics::install(&ui, settings_path);
    ui.window().set_fullscreen(true);
    ui.run()?;
    rt.shutdown_timeout(Duration::from_millis(250));
    Ok(())
}
