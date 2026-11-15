//! Streambot Touch: native Rust/Slint application entry point.
//! All view/model mutations are dispatched to Slint's event loop.

mod backend;
mod config;
mod dashboard_editor;
mod drawer;
mod notifications;
mod state;
mod ui_bridge;
mod ui_handlers;

use crate::{config::Settings, state::store::Store};
use serde_json::Value;
use slint::ComponentHandle;
use std::{
    sync::{Arc, Mutex},
    time::Duration,
};
use tokio::sync::mpsc;

slint::include_modules!();

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let config = Settings::load();
    let ui = App::new()?;
    let store = Arc::new(Mutex::new(Store::default()));
    dashboard_editor::install(&ui, store.clone());
    drawer::install(&ui);
    let weak = ui.as_weak();
    let (command_tx, command_rx) = mpsc::unbounded_channel::<(String, Value)>();
    let (event_tx, event_rx) = mpsc::unbounded_channel::<Value>();
    let rt = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()?;

    // Keep timer alive until the Slint event loop exits.
    let _model_sync = ui_handlers::install(&ui, store.clone(), command_tx);
    let _rt_guard = rt.enter();
    notifications::spawn(store.clone(), weak.clone(), event_rx);
    drop(_rt_guard);

    rt.spawn(backend::cava::cava_client(config.clone(), weak.clone()));
    rt.spawn(backend::run(config, event_tx, weak, store, command_rx));
    ui.run()?;
    rt.shutdown_timeout(Duration::from_millis(250));
    Ok(())
}
