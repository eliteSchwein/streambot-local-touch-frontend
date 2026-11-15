use crate::{state::store::Store, App};
use serde_json::{json, Value};
use slint::ComponentHandle;
use std::{
    cell::RefCell,
    rc::Rc,
    sync::{Arc, Mutex},
    time::Duration,
};
use tokio::sync::mpsc;

fn send(tx: &mpsc::UnboundedSender<(String, Value)>, method: &str, params: Value) {
    let _ = tx.send((method.into(), params));
}

pub(crate) fn install(
    ui: &App,
    store: Arc<Mutex<Store>>,
    command_tx: mpsc::UnboundedSender<(String, Value)>,
) -> slint::Timer {
    let macro_keys = Rc::new(RefCell::new(Vec::<String>::new()));
    let auto_items = Rc::new(RefCell::new(Vec::<Value>::new()));
    let point_items = Rc::new(RefCell::new(Vec::<Value>::new()));
    let audio_keys = Rc::new(RefCell::new(Vec::<String>::new()));

    {
        let tx = command_tx.clone();
        ui.on_remove_interaction(move |uuid| {
            send(&tx, "remove_interaction", json!({"uuid": uuid.as_str()}));
        });
    }
    {
        let tx = command_tx.clone();
        let items = macro_keys.clone();
        ui.on_trigger_macro(move |index| {
            if let Some(name) = items.borrow().get(index as usize) {
                send(&tx, "trigger_macro", json!({"macro": name}));
            }
        });
    }
    {
        let tx = command_tx.clone();
        ui.on_trigger_dashboard_macro(move |name| {
            send(&tx, "trigger_macro", json!({"macro": name.as_str()}));
        });
    }
    {
        let tx = command_tx.clone();
        let items = auto_items.clone();
        ui.on_toggle_dashboard_auto_macro(move |name| {
            if let Some(item) = items.borrow().iter().find(|item| item.get("name").and_then(Value::as_str) == Some(name.as_str())) {
                send(&tx, "toggle_auto_macro", json!({"name": name.as_str(), "enable": !item.get("enabled").and_then(Value::as_bool).unwrap_or(false)}));
            }
        });
    }
    {
        let tx = command_tx.clone();
        let items = auto_items.clone();
        ui.on_toggle_auto_macro(move |index| {
            if let Some(item) = items.borrow().get(index as usize) {
                send(&tx, "toggle_auto_macro", json!({"name":item.get("name"), "enable": !item.get("enabled").and_then(Value::as_bool).unwrap_or(false)}));
            }
        });
    }
    {
        let tx = command_tx.clone();
        let items = point_items.clone();
        ui.on_toggle_channel_point(move |index| {
            if let Some(point) = items.borrow().get(index as usize) {
                send(
                    &tx,
                    "toggle_channel_point",
                    json!({"state":"toggle", "channel_point":point}),
                );
            }
        });
    }
    {
        let tx = command_tx.clone();
        ui.on_music_action(move |action| {
            send(
                &tx,
                &format!("music_{}", action.replace('-', "_")),
                json!({}),
            );
        });
    }
    {
        let tx = command_tx.clone();
        ui.on_speedtest_start(move || send(&tx, "speedtest", json!({"action":"start"})));
    }
    {
        let tx = command_tx.clone();
        ui.on_update_refresh(move || send(&tx, "update_refresh", json!({})));
    }
    {
        let tx = command_tx.clone();
        let items = audio_keys.clone();
        ui.on_change_volume(move |idx, volume| {
            if let Some(name) = items.borrow().get(idx as usize) {
                send(&tx, "set_volume", json!({"interface":name,"volume":volume}));
            }
        });
    }

    // An asynchronous handler can't own non-Send Rc/RefCell mappings. Refresh them on
    // the Slint event loop from the synchronized backend store whenever their models change.
    let refresh_store = store.clone();
    let ui_weak = ui.as_weak();
    let refresh_macro_keys = macro_keys.clone();
    let refresh_auto_items = auto_items.clone();
    let refresh_point_items = point_items.clone();
    let refresh_audio_keys = audio_keys.clone();
    let refresh_timer = slint::Timer::default();
    refresh_timer.start(
        slint::TimerMode::Repeated,
        Duration::from_millis(250),
        move || {
            if ui_weak.upgrade().is_none() {
                return;
            }
            if let Ok(guard) = refresh_store.lock() {
                *refresh_macro_keys.borrow_mut() = guard.macros.clone();
                *refresh_auto_items.borrow_mut() = guard.auto_macros.clone();
                *refresh_point_items.borrow_mut() = guard.points.clone();
                *refresh_audio_keys.borrow_mut() = guard.audio.clone();
            }
        },
    );
    refresh_timer
}
