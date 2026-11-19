use crate::{network::NetworkManager, ui_bridge::ui_event, App};
use slint::{ComponentHandle, Model, ModelRc, Timer, TimerMode, VecModel};
use std::{
    process::{Command, Output},
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

fn output(bin: &str, args: &[&str]) -> Result<String, String> {
    let result = command(bin, args)
        .output()
        .map_err(|e| format!("{bin}: {e}"))?;
    command_output(result)
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

enum Request {
    Refresh,
    Close,
    Action(String, String, String),
}

#[derive(Default)]
struct Drawer {
    commander_url: Option<String>,
    last_wifi_scan: Option<Instant>,
    network: NetworkManager,
}

impl Drawer {
    fn action(&mut self, action: &str, id: &str, password: &str) -> Result<(), String> {
        if matches!(action, "wifi-on" | "wifi-off") {
            self.last_wifi_scan = None;
        }
        zbus::block_on(self.network.action(action, id, password))
    }

    fn refresh(
        &mut self,
        ui: &slint::Weak<App>,
        port: u16,
        action_result: Option<Result<(), String>>,
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
        let request_scan = self
            .last_wifi_scan
            .is_none_or(|last| last.elapsed() >= Duration::from_secs(20));
        if request_scan {
            self.last_wifi_scan = Some(Instant::now());
        }
        match zbus::block_on(self.network.snapshot(request_scan)) {
            Ok(snapshot) => {
                if !snapshot.wifi_enabled {
                    self.last_wifi_scan = None;
                }
                ui_event(ui, move |app| {
                    app.set_drawer_network_error("".into());
                    app.set_wifi_available(snapshot.wifi_available);
                    app.set_wifi_enabled(snapshot.wifi_enabled);
                    update_rows(app.get_ethernet(), snapshot.ethernet, |rows| {
                        app.set_ethernet(rows)
                    });
                    update_rows(app.get_wifi(), snapshot.wifi, |rows| app.set_wifi(rows));
                    update_rows(app.get_saved_wifi(), snapshot.saved, |rows| {
                        app.set_saved_wifi(rows)
                    });
                });
            }
            Err(error) => ui_event(ui, move |app| {
                app.set_drawer_network_error(error.into());
            }),
        }
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
}
