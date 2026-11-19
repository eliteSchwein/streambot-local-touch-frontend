use crate::{ui_bridge::ui_event, App, EthernetRow, SavedWifiRow, WifiRow};
use slint::{ComponentHandle, Model, ModelRc, Timer, TimerMode, VecModel};
use std::{
    io::Write,
    process::{Command, Output, Stdio},
    sync::mpsc,
    time::{Duration, Instant},
};

fn command(bin: &str, args: &[&str]) -> Command {
    let mut command = Command::new(bin);
    command.env("LC_ALL", "C").args(args);
    command
}

fn command_output(result: Output) -> Result<String, String> {
    let stdout = clean_output(&result.stdout);
    if result.status.success()
        && !stdout
            .lines()
            .any(|line| line.starts_with("Failed to ") || line.starts_with("No default controller"))
    {
        Ok(stdout)
    } else {
        let stderr = clean_output(&result.stderr);
        if !stderr.is_empty() {
            Err(stderr)
        } else if !stdout.is_empty() {
            Err(stdout)
        } else {
            Err(format!("Command exited with {}", result.status))
        }
    }
}

fn clean_output(bytes: &[u8]) -> String {
    let input = String::from_utf8_lossy(bytes);
    let mut chars = input.chars().peekable();
    let mut result = String::new();
    while let Some(c) = chars.next() {
        if c == '\x1b' && chars.next_if_eq(&'[').is_some() {
            while chars.next().is_some_and(|c| !('@'..='~').contains(&c)) {}
        } else if !c.is_control() || c == '\n' || c == '\t' {
            result.push(c);
        }
    }
    result.trim_end_matches('\n').into()
}

pub(crate) fn output(bin: &str, args: &[&str]) -> Result<String, String> {
    let result = command(bin, args)
        .output()
        .map_err(|e| format!("{bin}: {e}"))?;
    command_output(result)
}

fn nm(args: &[&str]) -> Result<String, String> {
    let mut argv = vec!["--wait", "20"];
    argv.extend_from_slice(args);
    output("nmcli", &argv)
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

fn ethernet_rows(list: &str) -> Vec<EthernetRow> {
    list.lines()
        .filter_map(|line| {
            let f = fields(line);
            let [id, kind, state] = f.as_slice() else {
                return None;
            };
            if kind != "ethernet" {
                return None;
            }
            let connected = state == "connected" || state == "connected (externally)";
            let autoconnect = nm(&["-g", "GENERAL.AUTOCONNECT", "device", "show", id])
                .is_ok_and(|value| value == "yes");
            Some(EthernetRow {
                id: id.as_str().into(),
                connected,
                enabled: connected || autoconnect,
            })
        })
        .collect()
}

fn saved_wifi_rows() -> Result<Vec<SavedWifiRow>, String> {
    Ok(
        nm(&["-t", "-f", "UUID,NAME,TYPE,DEVICE", "connection", "show"])?
            .lines()
            .filter_map(|line| {
                let f = fields(line);
                let [id, name, kind, device] = f.as_slice() else {
                    return None;
                };
                if kind != "802-11-wireless" && kind != "wifi" {
                    return None;
                }
                let ssid = nm(&[
                    "-e",
                    "no",
                    "-g",
                    "802-11-wireless.ssid",
                    "connection",
                    "show",
                    "uuid",
                    id,
                ])
                .unwrap_or_default();
                Some(SavedWifiRow {
                    id: id.as_str().into(),
                    name: name.as_str().into(),
                    ssid: ssid.into(),
                    connected: !device.is_empty() && device != "--",
                })
            })
            .collect(),
    )
}

fn wifi_rows(list: &str, saved: &[SavedWifiRow]) -> Vec<WifiRow> {
    let mut rows: Vec<_> = list
        .lines()
        .filter_map(|line| {
            let f = fields(line);
            let [id, name, security, active, signal, device] = f.as_slice() else {
                return None;
            };
            if name.is_empty() {
                return None;
            }
            let profile = saved.iter().find(|profile| profile.ssid.as_str() == name);
            Some(WifiRow {
                id: id.as_str().into(),
                name: name.as_str().into(),
                device: device.as_str().into(),
                secured: !security.is_empty() && security != "--",
                connected: active == "*",
                signal: signal.parse::<i32>().unwrap_or_default().clamp(0, 100),
                profile: profile.map(|p| p.id.clone()).unwrap_or_default(),
            })
        })
        .collect();
    rows.sort_by_key(|row| (!row.connected, std::cmp::Reverse(row.signal)));
    let mut seen = std::collections::HashSet::new();
    rows.retain(|row| seen.insert((row.name.clone(), row.secured)));
    rows
}

fn route_address(route: &str) -> Option<std::net::Ipv4Addr> {
    route
        .split_whitespace()
        .skip_while(|v| *v != "src")
        .nth(1)?
        .parse()
        .ok()
}

fn lan_address(addresses: &str) -> Option<std::net::Ipv4Addr> {
    addresses
        .lines()
        .filter_map(|line| {
            let mut fields = line.split_whitespace();
            fields.next()?;
            let interface = fields.next()?;
            if interface == "lo" {
                return None;
            }
            fields.next()?;
            let address: std::net::Ipv4Addr = fields.next()?.split('/').next()?.parse().ok()?;
            (!address.is_loopback() && !address.is_link_local()).then_some(address)
        })
        .next()
}

fn commander_url(port: u16) -> String {
    let ip = output("ip", &["-4", "route", "get", "1.1.1.1"])
        .ok()
        .and_then(|route| route_address(&route))
        .or_else(|| {
            output("ip", &["-o", "-4", "addr", "show", "up", "scope", "global"])
                .ok()
                .and_then(|addresses| lan_address(&addresses))
        });
    ip.map_or_else(String::new, |ip| format!("http://{ip}:{port}/commander"))
}

pub(crate) fn commander_qr(url: &str) -> Option<image::RgbImage> {
    if url.is_empty() {
        return None;
    }
    let code = qrcode::QrCode::new(url.as_bytes()).ok()?;
    let quiet_zone = 4;
    let scale = 8;
    let size = ((code.width() + 2 * quiet_zone) * scale) as u32;
    Some(image::RgbImage::from_fn(size, size, |x, y| {
        let x = (x as usize / scale).checked_sub(quiet_zone);
        let y = (y as usize / scale).checked_sub(quiet_zone);
        let dark = x.zip(y).is_some_and(|(x, y)| {
            x < code.width() && y < code.width() && code[(x, y)] == qrcode::Color::Dark
        });
        image::Rgb([if dark { 0 } else { 255 }; 3])
    }))
}

fn connect_wifi(id: &str, password: &str) -> Result<String, String> {
    if password.is_empty() {
        return nm(&["device", "wifi", "connect", id]);
    }
    // Feed the nmcli password prompt through stdin so the key stays out of argv.
    let mut child = command(
        "nmcli",
        &["--ask", "--wait", "20", "device", "wifi", "connect", id],
    )
    .stdin(Stdio::piped())
    .stdout(Stdio::null())
    .stderr(Stdio::piped())
    .spawn()
    .map_err(|e| e.to_string())?;
    if let Some(mut input) = child.stdin.take() {
        let _ = writeln!(input, "{password}");
    }
    command_output(child.wait_with_output().map_err(|e| e.to_string())?)
}

enum Request {
    Refresh,
    Close,
    Action(String, String, String),
}

#[derive(Default)]
struct Drawer {
    commander_url: Option<String>,
    last_wifi_scan: Option<Instant>,
}

impl Drawer {
    fn action(&mut self, action: &str, id: &str, password: &str) -> Result<String, String> {
        match action {
            "ethernet-on" => nm(&["device", "set", id, "autoconnect", "yes"])
                .and_then(|_| nm(&["device", "connect", id])),
            "ethernet-off" => nm(&["device", "set", id, "autoconnect", "no"])
                .and_then(|_| nm(&["device", "disconnect", id])),
            "wifi-on" => {
                self.last_wifi_scan = None;
                nm(&["radio", "wifi", "on"])
            }
            "wifi-off" => nm(&["radio", "wifi", "off"]),
            "wifi-connect" => connect_wifi(id, password),
            "wifi-disconnect" => nm(&["device", "disconnect", id]),
            "wifi-saved" => nm(&["connection", "up", "uuid", id]),
            "wifi-forget" => nm(&["connection", "delete", "uuid", id]),
            _ => Err("Unknown device action".into()),
        }
    }

    fn refresh(
        &mut self,
        ui: &slint::Weak<App>,
        port: u16,
        action_result: Option<Result<String, String>>,
    ) {
        self.refresh_web(ui, port);
        self.refresh_network(ui);
        let finished_action = action_result.is_some();
        let action_error = action_result.and_then(Result::err);
        ui_event(ui, move |app| {
            if let Some(error) = action_error {
                app.set_drawer_error(error.into());
            }
            if finished_action {
                app.set_drawer_busy(false);
            } else {
                app.set_drawer_refreshing(false);
            }
        });
    }

    fn refresh_web(&mut self, ui: &slint::Weak<App>, port: u16) {
        let url = commander_url(port);
        if self.commander_url.as_ref() == Some(&url) {
            return;
        }
        let qr = commander_qr(&url);
        self.commander_url = Some(url.clone());
        ui_event(ui, move |app| {
            app.set_commander_url(url.into());
            app.set_commander_qr(
                qr.map(|image| {
                    slint::Image::from_rgb8(slint::SharedPixelBuffer::clone_from_slice(
                        image.as_raw(),
                        image.width(),
                        image.height(),
                    ))
                })
                .unwrap_or_default(),
            );
        });
    }

    fn refresh_network(&mut self, ui: &slint::Weak<App>) {
        let devices = nm(&["-t", "-f", "DEVICE,TYPE,STATE", "device", "status"]);
        let radio = nm(&["-t", "-f", "WIFI-HW,WIFI", "radio"]);
        let wifi_available = devices.as_ref().is_ok_and(|list| {
            list.lines().map(fields).any(|fields| {
                matches!(fields.as_slice(), [_, kind, state] if kind == "wifi" && state != "unmanaged")
            })
        }) && radio.as_ref().is_ok_and(|s| s.starts_with("enabled:"));
        let ethernet = devices.map(|list| ethernet_rows(&list));
        let wifi_enabled = wifi_available && radio.as_ref().is_ok_and(|s| s == "enabled:enabled");
        let saved = saved_wifi_rows();
        let wifi = if wifi_enabled {
            if self
                .last_wifi_scan
                .is_none_or(|last| last.elapsed() >= Duration::from_secs(20))
            {
                self.last_wifi_scan = Some(Instant::now());
                // Request a scan without waiting for it. Read the cached results below.
                let _ = output("nmcli", &["--wait", "0", "device", "wifi", "rescan"]);
            }
            nm(&[
                "-t",
                "-f",
                "BSSID,SSID,SECURITY,IN-USE,SIGNAL,DEVICE",
                "device",
                "wifi",
                "list",
                "--rescan",
                "no",
            ])
            .and_then(|list| {
                saved
                    .as_ref()
                    .map(|saved| wifi_rows(&list, saved))
                    .map_err(Clone::clone)
            })
        } else {
            Ok(Vec::new())
        };
        ui_event(ui, move |app| {
            let network_error = ethernet
                .as_ref()
                .err()
                .or(radio.as_ref().err())
                .or(wifi.as_ref().err())
                .or(saved.as_ref().err());
            app.set_drawer_network_error(network_error.map_or("", String::as_str).into());
            if radio.is_ok() && ethernet.is_ok() {
                app.set_wifi_available(wifi_available);
                app.set_wifi_enabled(wifi_enabled);
            }
            if let Ok(ethernet) = ethernet {
                update_rows(app.get_ethernet(), ethernet, |rows| app.set_ethernet(rows));
            }
            if let Ok(wifi) = wifi {
                update_rows(app.get_wifi(), wifi, |rows| app.set_wifi(rows));
            }
            if let Ok(saved) = saved {
                update_rows(app.get_saved_wifi(), saved, |rows| app.set_saved_wifi(rows));
            }
        });
    }
}

pub(crate) fn update_rows<T: Clone + PartialEq + 'static>(
    current: ModelRc<T>,
    rows: Vec<T>,
    apply: impl FnOnce(ModelRc<T>),
) {
    if current.iter().ne(rows.iter().cloned()) {
        apply(ModelRc::new(VecModel::from(rows)));
    }
}

fn request_refresh(ui: &App, tx: &mpsc::Sender<Request>) {
    if !ui.get_drawer_refreshing() && !ui.get_drawer_busy() && tx.send(Request::Refresh).is_ok() {
        ui.set_drawer_refreshing(true);
    }
}

pub(crate) fn install(ui: &App, port: u16) -> Timer {
    let (tx, rx) = mpsc::channel();
    let weak = ui.as_weak();
    std::thread::spawn(move || {
        let mut drawer = Drawer::default();
        while let Ok(request) = rx.recv() {
            match request {
                Request::Refresh => drawer.refresh(&weak, port, None),
                Request::Close => drawer.last_wifi_scan = None,
                Request::Action(action, id, password) => {
                    let result = drawer.action(&action, &id, &password);
                    drawer.refresh(&weak, port, Some(result));
                }
            }
        }
    });
    let weak = ui.as_weak();
    let bluetooth = crate::bluetooth::start(ui.as_weak());
    let bluetooth_visibility = bluetooth.clone();
    let visibility_tx = tx.clone();
    ui.on_drawer_visibility(move |open| {
        if let Some(app) = weak.upgrade() {
            if open {
                request_refresh(&app, &visibility_tx);
                crate::bluetooth::request_refresh(&app, &bluetooth_visibility);
            } else {
                let _ = visibility_tx.send(Request::Close);
                let _ = bluetooth_visibility.send(crate::bluetooth::Request::Close);
                app.set_bluetooth_scanning(false);
            }
        }
    });
    let weak = ui.as_weak();
    let action_tx = tx.clone();
    let bluetooth_action = bluetooth.clone();
    ui.on_drawer_command(move |action, id, password| {
        let Some(app) = weak.upgrade() else { return };
        if action.starts_with("bt-") || action.starts_with("bluetooth-") {
            if !app.get_bluetooth_busy()
                && bluetooth_action
                    .send(crate::bluetooth::Request::Action(action.into(), id.into()))
                    .is_ok()
            {
                app.set_bluetooth_error("".into());
                app.set_bluetooth_busy(true);
            }
        } else if !app.get_drawer_busy() {
            if action_tx
                .send(Request::Action(action.into(), id.into(), password.into()))
                .is_ok()
            {
                app.set_drawer_error("".into());
                app.set_drawer_busy(true);
            }
        }
    });
    let timer = Timer::default();
    let weak = ui.as_weak();
    timer.start(TimerMode::Repeated, Duration::from_secs(3), move || {
        if let Some(app) = weak.upgrade().filter(|app| app.get_network_drawer_open()) {
            request_refresh(&app, &tx);
            crate::bluetooth::request_refresh(&app, &bluetooth);
        }
    });
    timer
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn web_access_has_a_qr_code_for_a_lan_without_a_default_route() {
        assert_eq!(route_address(""), None);
        let ip = lan_address("2: wlan0 inet 192.168.42.2/24 brd 192.168.42.255 scope global wlan0")
            .unwrap();
        let qr = commander_qr(&format!("http://{ip}:3000/commander")).unwrap();
        assert_eq!(qr.width(), qr.height());
        assert_eq!(qr.get_pixel(0, 0).0, [255; 3]);
        assert_eq!(qr.get_pixel(32, 32).0, [0; 3]);
    }

    #[test]
    fn wifi_rows_keep_active_access_point_and_match_saved_ssid() {
        let saved = [SavedWifiRow {
            id: "profile".into(),
            ssid: "studio:east".into(),
            ..Default::default()
        }];
        let rows = wifi_rows(
            "AA\\:BB:studio\\:east:WPA2::98:wlan0\nCC\\:DD:studio\\:east:WPA2:*:61:wlan0\nEE\\:FF:Guest:--::28:wlan0",
            &saved,
        );
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0].id, "CC:DD");
        assert_eq!(rows[0].profile, "profile");
        assert_eq!(rows[0].signal, 61);
        assert!(rows[0].connected);
        assert!(!rows[1].secured);
    }
}
