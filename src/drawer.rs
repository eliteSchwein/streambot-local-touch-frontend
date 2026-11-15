//! Native system drawer integration (NetworkManager and BlueZ command line clients).
//! No external UI process is used. Commands are executed off the UI thread.
use crate::App;
use slint::ComponentHandle;
use std::process::Command;

fn output(bin: &str, args: &[&str]) -> String {
    match Command::new(bin).args(args).output() {
        Ok(result) if result.status.success() => {
            let value = String::from_utf8_lossy(&result.stdout).trim().to_owned();
            if value.is_empty() {
                "No devices reported".to_string()
            } else {
                value
            }
        }
        Ok(result) => format!("{}", String::from_utf8_lossy(&result.stderr).trim()),
        Err(e) => format!("{bin} unavailable: {e}"),
    }
}

fn refresh(ui: slint::Weak<App>) {
    std::thread::spawn(move || {
        let network = output(
            "nmcli",
            &[
                "-t",
                "-f",
                "DEVICE,TYPE,STATE,CONNECTION",
                "device",
                "status",
            ],
        );
        let bluetooth = output("bluetoothctl", &["show"]);
        let _ = slint::invoke_from_event_loop(move || {
            if let Some(ui) = ui.upgrade() {
                ui.set_drawer_network(network.into());
                ui.set_drawer_bluetooth(bluetooth.into());
            }
        });
    });
}

pub(crate) fn install(ui: &App) {
    let weak = ui.as_weak();
    ui.on_refresh_drawer(move || refresh(weak.clone()));
    let weak = ui.as_weak();
    ui.on_drawer_command(move |action| {
        let weak = weak.clone();
        std::thread::spawn(move || {
            let (bin, args): (&str, &[&str]) = match action.as_str() {
                "wifi-on" => ("nmcli", &["radio", "wifi", "on"]),
                "wifi-off" => ("nmcli", &["radio", "wifi", "off"]),
                "bluetooth-on" => ("bluetoothctl", &["power", "on"]),
                "bluetooth-off" => ("bluetoothctl", &["power", "off"]),
                _ => return,
            };
            let result = Command::new(bin).args(args).output();
            let feedback = match result {
                Ok(result) if result.status.success() => format!("{action} succeeded"),
                Ok(result) => format!(
                    "{action}: {}",
                    String::from_utf8_lossy(&result.stderr).trim()
                ),
                Err(e) => format!("{action}: {e}"),
            };
            let _ = slint::invoke_from_event_loop(move || {
                if let Some(ui) = weak.upgrade() {
                    ui.set_feedback(feedback.into());
                    ui.invoke_refresh_drawer();
                }
            });
        });
    });
}
