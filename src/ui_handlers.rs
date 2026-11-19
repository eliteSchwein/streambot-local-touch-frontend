use crate::App;
use serde_json::{json, Value};
use slint::{ComponentHandle, Model};
use tokio::sync::mpsc;

fn send(tx: &mpsc::UnboundedSender<(String, Value)>, method: &str, params: Value) {
    let _ = tx.send((method.into(), params));
}

pub(crate) fn install(ui: &App, command_tx: mpsc::UnboundedSender<(String, Value)>) {
    ui.set_language(crate::config::dashboard::language().into());
    let weak = ui.as_weak();
    ui.on_choose_language(move |lang| {
        if let Some(app) = weak.upgrade() {
            match crate::config::dashboard::save_language(&lang) {
                Ok(()) => app.set_language(lang),
                Err(e) => app.set_feedback(e.to_string().into()),
            }
        }
    });
    install_update_queue(ui, command_tx.clone());
    ui.on_matches(|label, query| label.to_lowercase().contains(&query.trim().to_lowercase()));
    {
        let tx = command_tx.clone();
        ui.on_remove_interaction(move |uuid| {
            send(&tx, "remove_interaction", json!({"uuid": uuid.as_str()}));
        });
    }
    let tx = command_tx.clone();
    ui.on_trigger_macro(move |name| send(&tx, "trigger_macro", json!({"macro":name.as_str()})));
    let tx = command_tx.clone();
    ui.on_toggle_auto_macro(move |name, enable| {
        send(
            &tx,
            "toggle_auto_macro",
            json!({"name":name.as_str(),"enable":enable}),
        )
    });
    let tx = command_tx.clone();
    ui.on_toggle_channel_point(move |payload| {
        if let Ok(point) = serde_json::from_str::<Value>(&payload) {
            send(
                &tx,
                "toggle_channel_point",
                json!({"state":"toggle","channel_point":point}),
            );
        }
    });
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
    let tx = command_tx.clone();
    ui.on_run_update(move |name| send(&tx, "update", json!({"name":name.as_str()})));
    let tx = command_tx.clone();
    let weak = ui.as_weak();
    ui.on_change_volume(move |item, volume, mute| {
        if item.physical {
            crate::audio::physical_volume(
                weak.clone(),
                item.id.to_string(),
                (!mute).then_some(volume),
            );
        } else {
            send(
                &tx,
                "set_volume",
                json!({"interface":item.id.as_str(),"volume":volume}),
            );
        }
    });
    let tx = command_tx.clone();
    ui.on_link_output(move |id, output, linked| {
        send(
            &tx,
            "link_sink",
            json!({"interface":id.as_str(),"output":output.as_str(),"linked":linked}),
        )
    });
    let tx = command_tx.clone();
    ui.on_per_link_control(move |id, enabled| {
        send(
            &tx,
            "set_per_link_control",
            json!({"interface":id.as_str(),"enabled":enabled}),
        )
    });
    ui.on_link_volume(move |id, output, volume| {
        send(
            &command_tx,
            "set_link_volume",
            json!({"interface":id.as_str(),"output":output.as_str(),"volume":volume}),
        )
    });
}

fn install_update_queue(ui: &App, tx: mpsc::UnboundedSender<(String, Value)>) {
    use std::{cell::RefCell, collections::VecDeque, rc::Rc};
    let queue = Rc::new(RefCell::new(VecDeque::<String>::new()));
    let weak = ui.as_weak();
    let jobs = queue.clone();
    ui.on_update_all(move || {
        let Some(app) = weak.upgrade() else { return };
        if !app.get_updating_manager().is_empty() || app.get_updates().iter().any(|r| r.busy) {
            return;
        }
        let mut names: Vec<_> = app
            .get_updates()
            .iter()
            .filter(|r| r.active)
            .map(|r| r.id.to_string())
            .collect();
        names.sort_by_key(|name| name == "backend");
        if names.is_empty() {
            return;
        }
        *jobs.borrow_mut() = names.into();
        app.invoke_advance_updates();
    });
    let weak = ui.as_weak();
    let jobs = queue.clone();
    ui.on_advance_updates(move || {
        let Some(app) = weak.upgrade() else { return };
        let current = app.get_updating_manager();
        let rows = app.get_updates();
        if rows.iter().any(|r| r.busy || (r.id == current && r.active)) {
            return;
        }
        while let Some(name) = jobs.borrow_mut().pop_front() {
            if rows.iter().any(|r| r.id.as_str() == name && r.active) {
                app.set_updating_manager(name.as_str().into());
                send(&tx, "update", json!({"name":name}));
                return;
            }
        }
        if !current.is_empty() {
            app.set_updating_manager("".into());
            send(&tx, "update_refresh", json!({}));
        }
    });
    let weak = ui.as_weak();
    ui.on_cancel_updates(move || {
        queue.borrow_mut().clear();
        if let Some(app) = weak.upgrade() {
            app.set_updating_manager("".into());
        }
    });
}
