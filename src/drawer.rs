use crate::{ui_bridge::ui_event, ActionRow, App};
use slint::{ComponentHandle, ModelRc, VecModel};
use std::{
    io::Write,
    process::{Command, Stdio},
};

fn output(bin: &str, args: &[&str]) -> Result<String, String> {
    let result = Command::new(bin)
        .env("LC_ALL", "C")
        .args(args)
        .output()
        .map_err(|e| format!("{bin}: {e}"))?;
    if result.status.success() {
        Ok(String::from_utf8_lossy(&result.stdout).trim_end().into())
    } else {
        Err(String::from_utf8_lossy(&result.stderr).trim().into())
    }
}

// nmcli escapes colons and backslashes in terse output.
fn fields(line: &str) -> Vec<String> {
    let mut parts = vec![String::new()];
    let mut escaped = false;
    for c in line.chars() {
        if c == ':' && !escaped {
            parts.push(String::new());
        } else if c == '\\' && !escaped {
            escaped = true;
        } else {
            parts.last_mut().unwrap().push(c);
            escaped = false;
        }
    }
    parts
}

type Rows = Vec<(String, String, bool)>;
fn model(rows: Rows) -> ModelRc<ActionRow> {
    ModelRc::new(VecModel::from(
        rows.into_iter()
            .map(|(id, label, active)| ActionRow {
                id: id.into(),
                label: label.into(),
                active,
            })
            .collect::<Vec<_>>(),
    ))
}

fn refresh(ui: slint::Weak<App>, port: u16) {
    std::thread::spawn(move || {
        let network = output(
            "nmcli",
            &["-t", "-f", "DEVICE,TYPE,STATE", "device", "status"],
        )
        .unwrap_or_else(|e| e);
        let ethernet = network
            .lines()
            .filter_map(|line| {
                let f = fields(line);
                match f.as_slice() {
                    [id, kind, state] if kind == "ethernet" => {
                        Some((id.clone(), format!("{id}  {state}"), state == "connected"))
                    }
                    _ => None,
                }
            })
            .collect();
        let bluetooth = output("bluetoothctl", &["show"])
            .map(|s| {
                s.lines()
                    .find(|l| l.contains("Powered:"))
                    .unwrap_or("")
                    .trim()
                    .to_owned()
            })
            .unwrap_or_else(|e| e);
        let mut wifi = Rows::new();
        for line in output(
            "nmcli",
            &[
                "-t",
                "-f",
                "BSSID,SSID,SECURITY,IN-USE",
                "device",
                "wifi",
                "list",
            ],
        )
        .unwrap_or_default()
        .lines()
        {
            let f = fields(line);
            if let [id, ssid, security, active] = f.as_slice() {
                if !ssid.is_empty() {
                    wifi.push((id.clone(), format!("{ssid}  {security}"), active == "*"));
                }
            }
        }
        let mut saved = Rows::new();
        for line in output("nmcli", &["-t", "-f", "UUID,NAME,TYPE", "con", "show"])
            .unwrap_or_default()
            .lines()
        {
            let f = fields(line);
            if let [id, name, kind] = f.as_slice() {
                if kind == "802-11-wireless" || kind == "wifi" {
                    saved.push((id.clone(), name.clone(), false));
                }
            }
        }
        let connected = output("bluetoothctl", &["devices", "Connected"]).unwrap_or_default();
        let mut devices = Rows::new();
        for line in output("bluetoothctl", &["devices"])
            .unwrap_or_default()
            .lines()
        {
            if let Some((id, name)) = line.strip_prefix("Device ").and_then(|s| s.split_once(' ')) {
                devices.push((
                    id.into(),
                    name.into(),
                    connected
                        .lines()
                        .any(|s| s.split_whitespace().nth(1) == Some(id)),
                ));
            }
        }
        let address = output("ip", &["-4", "route", "get", "1.1.1.1"])
            .ok()
            .and_then(|s| {
                s.split_whitespace()
                    .skip_while(|v| *v != "src")
                    .nth(1)?
                    .parse::<std::net::Ipv4Addr>()
                    .ok()
            });
        let url = address.map_or_else(String::new, |ip| format!("http://{ip}:{port}/commander"));
        let qr = if url.is_empty() {
            None
        } else {
            Command::new("qrencode")
                .args(["-o", "-", "-s", "4", &url])
                .output()
                .ok()
                .and_then(|r| image::load_from_memory(&r.stdout).ok())
                .map(|i| i.to_rgb8())
        };
        ui_event(&ui, move |app| {
            app.set_drawer_network(network.into());
            app.set_drawer_bluetooth(bluetooth.into());
            app.set_ethernet(model(ethernet));
            app.set_wifi(model(wifi));
            app.set_saved_wifi(model(saved));
            app.set_devices(model(devices));
            app.set_commander_url(url.into());
            app.set_commander_qr(
                qr.map(|i| {
                    slint::Image::from_rgb8(slint::SharedPixelBuffer::clone_from_slice(
                        i.as_raw(),
                        i.width(),
                        i.height(),
                    ))
                })
                .unwrap_or_default(),
            );
            app.set_drawer_busy(false);
        });
    });
}

fn connect_wifi(id: &str, password: &str) -> Result<String, String> {
    if password.is_empty() {
        return output("nmcli", &["--wait", "20", "dev", "wifi", "connect", id]);
    }
    let mut child = Command::new("nmcli")
        .args(["--ask", "--wait", "20", "dev", "wifi", "connect", id])
        .stdin(Stdio::piped())
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| e.to_string())?;
    if let Some(mut input) = child.stdin.take() {
        let _ = writeln!(input, "{password}");
    }
    let result = child.wait_with_output().map_err(|e| e.to_string())?;
    if result.status.success() {
        Ok(String::new())
    } else {
        Err(String::from_utf8_lossy(&result.stderr).trim().into())
    }
}

pub(crate) fn install(ui: &App, port: u16) {
    let weak = ui.as_weak();
    ui.on_refresh_drawer(move || {
        if let Some(app) = weak.upgrade().filter(|a| !a.get_drawer_busy()) {
            app.set_drawer_busy(true);
            refresh(weak.clone(), port);
        }
    });
    let weak = ui.as_weak();
    ui.on_drawer_command(move |action, id, password| {
        let Some(app) = weak.upgrade().filter(|a| !a.get_drawer_busy()) else {
            return;
        };
        app.set_drawer_busy(true);
        let weak = weak.clone();
        std::thread::spawn(move || {
            let id = id.as_str();
            let result = match action.as_str() {
                "ethernet-on" => output("nmcli", &["device", "connect", id]),
                "ethernet-off" => output("nmcli", &["device", "disconnect", id]),
                "wifi-rescan" => output("nmcli", &["device", "wifi", "rescan"]),
                "wifi-on" => output("nmcli", &["radio", "wifi", "on"]),
                "wifi-off" => output("nmcli", &["radio", "wifi", "off"]),
                "wifi-connect" => connect_wifi(id, &password),
                "wifi-saved" => output("nmcli", &["con", "up", "uuid", id]),
                "wifi-forget" => output("nmcli", &["con", "delete", "uuid", id]),
                "bt-scan" => output("bluetoothctl", &["--timeout", "8", "scan", "on"]),
                "bt-pair" => output("bluetoothctl", &["--timeout", "20", "pair", id])
                    .and_then(|_| output("bluetoothctl", &["trust", id]))
                    .and_then(|_| output("bluetoothctl", &["connect", id])),
                "bt-connect" => output("bluetoothctl", &["connect", id]),
                "bt-disconnect" => output("bluetoothctl", &["disconnect", id]),
                "bt-remove" => output("bluetoothctl", &["remove", id]),
                "bluetooth-on" => output("bluetoothctl", &["power", "on"]),
                "bluetooth-off" => output("bluetoothctl", &["power", "off"]),
                _ => Err("Unknown device action".into()),
            };
            let feedback = result.map(|_| "Done".to_owned()).unwrap_or_else(|e| e);
            ui_event(&weak, move |app| app.set_feedback(feedback.into()));
            refresh(weak, port);
        });
    });
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn escaped_network_names_remain_one_field() {
        assert_eq!(
            fields(r"AA\:BB:studio\:east:WPA2:*"),
            ["AA:BB", "studio:east", "WPA2", "*"]
        );
    }
}
