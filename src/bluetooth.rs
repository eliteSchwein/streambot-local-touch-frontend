use crate::{
    drawer::{output, update_rows},
    ui_bridge::ui_event,
    App, BluetoothRow,
};
use std::{collections::HashMap, sync::mpsc, time::Duration};
use zbus::{
    blocking::{connection, fdo::ObjectManagerProxy, Connection, Proxy},
    fdo::ManagedObjects,
    zvariant::{OwnedObjectPath, OwnedValue},
};

const SERVICE: &str = "org.bluez";
const ADAPTER: &str = "org.bluez.Adapter1";
const DEVICE: &str = "org.bluez.Device1";

pub(crate) enum Request {
    Refresh,
    Close,
    Action(String, String),
}

fn flag(properties: &HashMap<String, OwnedValue>, key: &str) -> bool {
    properties
        .get(key)
        .and_then(|v| bool::try_from(v).ok())
        .unwrap_or(false)
}

fn text<'a>(properties: &'a HashMap<String, OwnedValue>, key: &str) -> Option<&'a str> {
    properties.get(key).and_then(|v| <&str>::try_from(v).ok())
}

fn adapter(objects: &ManagedObjects) -> Option<(&OwnedObjectPath, &HashMap<String, OwnedValue>)> {
    objects
        .iter()
        .filter_map(|(path, interfaces)| Some((path, interfaces.get(ADAPTER)?)))
        .min_by_key(|(path, props)| (!flag(props, "Powered"), path.as_str()))
}

fn devices<'a>(
    objects: &'a ManagedObjects,
    controller: &OwnedObjectPath,
) -> impl Iterator<Item = (&'a OwnedObjectPath, &'a HashMap<String, OwnedValue>)> {
    let prefix = format!("{}/", controller.as_str());
    objects.iter().filter_map(move |(path, interfaces)| {
        path.as_str()
            .starts_with(&prefix)
            .then(|| interfaces.get(DEVICE))
            .flatten()
            .map(|props| (path, props))
    })
}

fn rows(
    objects: &ManagedObjects,
    controller: &OwnedObjectPath,
) -> (Vec<BluetoothRow>, Vec<BluetoothRow>) {
    let mut paired = Vec::new();
    let mut discovered = Vec::new();
    for (_, props) in devices(objects, controller) {
        let Some(address) = text(props, "Address") else {
            continue;
        };
        let name = text(props, "Alias")
            .or_else(|| text(props, "Name"))
            .unwrap_or(address);
        let icon = text(props, "Icon").unwrap_or("");
        let kind = if ["audio", "headset", "headphone", "speaker"]
            .iter()
            .any(|kind| icon.contains(kind))
        {
            "SPK"
        } else if icon.contains("phone") {
            "PH"
        } else if icon.contains("computer") {
            "PC"
        } else if icon.contains("keyboard") || icon.contains("mouse") {
            "KB"
        } else {
            "BT"
        };
        let row = BluetoothRow {
            id: address.into(),
            name: name.into(),
            kind: kind.into(),
            connected: flag(props, "Connected"),
        };
        if flag(props, "Paired") {
            paired.push(row);
        } else {
            discovered.push(row);
        }
    }
    paired.sort_by_key(|row| (!row.connected, row.name.to_lowercase()));
    discovered.sort_by_key(|row| row.name.to_lowercase());
    (paired, discovered)
}

fn error_key(error: &str) -> &'static str {
    let error = error.to_ascii_lowercase();
    if error.contains("authenticationfailed") {
        "bluetooth_error_authentication_failed"
    } else if error.contains("authenticationrejected") {
        "bluetooth_error_authentication_rejected"
    } else if error.contains("authenticationcanceled") || error.contains("authenticationcancelled")
    {
        "bluetooth_error_authentication_canceled"
    } else if error.contains("connectionattemptfailed") {
        "bluetooth_error_connection_failed"
    } else if error.contains("timeout") || error.contains("timed out") {
        "bluetooth_error_timeout"
    } else if error.contains("notavailable") || error.contains("no longer available") {
        "bluetooth_error_not_available"
    } else {
        "bluetooth_error_generic"
    }
}

#[derive(Default)]
struct Bluetooth {
    connection: Option<Connection>,
    scanning: Option<OwnedObjectPath>,
}

impl Bluetooth {
    fn connection(&mut self) -> Result<&Connection, String> {
        if self.connection.is_none() {
            self.connection = Some(
                connection::Builder::system()
                    .and_then(|builder| builder.method_timeout(Duration::from_secs(10)).build())
                    .map_err(|error| error.to_string())?,
            );
        }
        Ok(self.connection.as_ref().unwrap())
    }

    fn objects(&mut self) -> Result<ManagedObjects, String> {
        let result = ObjectManagerProxy::builder(self.connection()?)
            .destination(SERVICE)
            .and_then(|builder| builder.path("/"))
            .and_then(|builder| builder.build())
            .map_err(|error| error.to_string())
            .and_then(|proxy| {
                proxy
                    .get_managed_objects()
                    .map_err(|error| error.to_string())
            });
        if result.is_err() {
            self.connection = None;
            self.scanning = None;
        }
        result
    }

    fn proxy<'a>(
        &mut self,
        path: &'a OwnedObjectPath,
        interface: &'static str,
    ) -> Result<Proxy<'a>, String> {
        Proxy::new(self.connection()?, SERVICE, path.as_str(), interface)
            .map_err(|error| error.to_string())
    }

    fn stop_scan(&mut self) -> Result<(), String> {
        let Some(path) = self.scanning.take() else {
            return Ok(());
        };
        let result = self
            .proxy(&path, ADAPTER)?
            .call::<_, _, ()>("StopDiscovery", &())
            .map_err(|error| error.to_string());
        if result.is_err() {
            // Closing the connection also releases our discovery session.
            self.connection = None;
        }
        result
    }

    fn action(&mut self, action: &str, id: &str) -> Result<(), String> {
        if action == "bt-stop-scan" {
            return self.stop_scan();
        }
        let objects = self.objects()?;
        let (path, _) = adapter(&objects).ok_or("No Bluetooth adapter found")?;
        if action == "bt-scan" {
            if self.scanning.is_none() {
                // BlueZ's default discovery transport covers Classic and LE.
                self.proxy(path, ADAPTER)?
                    .call::<_, _, ()>("StartDiscovery", &())
                    .map_err(|error| error.to_string())?;
                self.scanning = Some(path.clone());
            }
            return Ok(());
        }
        if matches!(action, "bluetooth-on" | "bluetooth-off") {
            if action == "bluetooth-off" {
                let _ = self.stop_scan();
            }
            return self
                .proxy(path, ADAPTER)?
                .set_property("Powered", action == "bluetooth-on")
                .map_err(|error| error.to_string());
        }
        let (device, props) = devices(&objects, path)
            .find(|(_, props)| text(props, "Address") == Some(id))
            .ok_or("Bluetooth device is no longer available")?;
        match action {
            "bt-pair" => {
                self.stop_scan()?;
                if !flag(props, "Paired") {
                    output(
                        "bluetoothctl",
                        &["--timeout", "20", "--agent", "NoInputNoOutput", "pair", id],
                    )?;
                }
                let proxy = self.proxy(device, DEVICE)?;
                if !proxy
                    .get_property::<bool>("Paired")
                    .map_err(|error| error.to_string())?
                {
                    return Err("BlueZ did not report the device as paired".into());
                }
                proxy
                    .set_property("Trusted", true)
                    .map_err(|error| error.to_string())?;
                if !proxy
                    .get_property::<bool>("Connected")
                    .map_err(|error| error.to_string())?
                {
                    proxy
                        .call::<_, _, ()>("Connect", &())
                        .map_err(|error| error.to_string())?;
                }
            }
            "bt-connect" | "bt-disconnect" => {
                let method = if action == "bt-connect" {
                    "Connect"
                } else {
                    "Disconnect"
                };
                self.proxy(device, DEVICE)?
                    .call::<_, _, ()>(method, &())
                    .map_err(|error| error.to_string())?;
            }
            "bt-remove" => {
                let _ = self.stop_scan();
                self.proxy(path, ADAPTER)?
                    .call::<_, _, ()>("RemoveDevice", &(device,))
                    .map_err(|error| error.to_string())?;
            }
            _ => return Err("Unknown Bluetooth action".into()),
        }
        Ok(())
    }

    fn refresh(&mut self, ui: &slint::Weak<App>, action: Option<Result<(), String>>) {
        let objects = self.objects();
        let controller = objects.as_ref().ok().and_then(adapter);
        let available = controller.is_some();
        let powered = controller.is_some_and(|(_, props)| flag(props, "Powered"));
        if self.scanning.as_ref().is_some_and(|path| {
            !controller.is_some_and(|(current, props)| current == path && flag(props, "Powered"))
        }) {
            let _ = self.stop_scan();
        }
        let scanning = self.scanning.is_some();
        let (paired, discovered) =
            if let (true, Ok(objects), Some((path, _))) = (powered, objects.as_ref(), controller) {
                rows(objects, path)
            } else {
                Default::default()
            };
        let finished_action = action.is_some();
        let error = action.and_then(Result::err).or_else(|| objects.err());
        ui_event(ui, move |app| {
            app.set_bluetooth_available(available);
            app.set_bluetooth_powered(powered);
            app.set_bluetooth_scanning(scanning && app.get_network_drawer_open());
            app.set_bluetooth_connected_count(paired.iter().filter(|r| r.connected).count() as i32);
            update_rows(app.get_paired_devices(), paired, |rows| {
                app.set_paired_devices(rows)
            });
            update_rows(app.get_discovered_devices(), discovered, |rows| {
                app.set_discovered_devices(rows)
            });
            if let Some(error) = error {
                eprintln!("BlueZ: {error}");
                app.set_bluetooth_error(error_key(&error).into());
            }
            if finished_action {
                app.set_bluetooth_busy(false);
            } else {
                app.set_bluetooth_refreshing(false);
            }
        });
    }
}

pub(crate) fn start(ui: slint::Weak<App>) -> mpsc::Sender<Request> {
    let (tx, rx) = mpsc::channel();
    std::thread::spawn(move || {
        let mut bluetooth = Bluetooth::default();
        for request in rx {
            match request {
                Request::Refresh => bluetooth.refresh(&ui, None),
                Request::Close => {
                    let _ = bluetooth.stop_scan();
                }
                Request::Action(action, id) => {
                    let result = bluetooth.action(&action, &id);
                    bluetooth.refresh(&ui, Some(result));
                }
            }
        }
    });
    tx
}

pub(crate) fn request_refresh(app: &App, tx: &mpsc::Sender<Request>) {
    if !app.get_bluetooth_refreshing()
        && !app.get_bluetooth_busy()
        && tx.send(Request::Refresh).is_ok()
    {
        app.set_bluetooth_refreshing(true);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bluez_snapshot_separates_paired_and_discovered_devices() {
        let controller = OwnedObjectPath::try_from("/org/bluez/hci0").unwrap();
        let device = |path, name, paired, connected| {
            (
                OwnedObjectPath::try_from(path).unwrap(),
                HashMap::from([(
                    DEVICE.try_into().unwrap(),
                    HashMap::from([
                        ("Address".into(), zbus::zvariant::Str::from(name).into()),
                        ("Alias".into(), zbus::zvariant::Str::from(name).into()),
                        ("Paired".into(), OwnedValue::from(paired)),
                        ("Connected".into(), OwnedValue::from(connected)),
                    ]),
                )]),
            )
        };
        let objects = ManagedObjects::from([
            device("/org/bluez/hci0/dev_01", "Speaker", true, true),
            device("/org/bluez/hci0/dev_02", "Headset", false, false),
            device("/org/bluez/hci1/dev_03", "Other adapter", true, true),
        ]);
        let (paired, discovered) = rows(&objects, &controller);
        assert_eq!(paired.len(), 1);
        assert_eq!(paired[0].name, "Speaker");
        assert!(paired[0].connected);
        assert_eq!(discovered.len(), 1);
        assert_eq!(discovered[0].name, "Headset");
    }

    #[test]
    #[ignore = "needs a powered BlueZ adapter"]
    fn live_discovery_probe() {
        let mut bluetooth = Bluetooth::default();
        let objects = bluetooth.objects().unwrap();
        assert!(adapter(&objects).is_some_and(|(_, props)| flag(props, "Powered")));
        bluetooth.action("bt-scan", "").unwrap();
        let discovery = bluetooth.objects();
        let stop = bluetooth.action("bt-stop-scan", "");
        stop.unwrap();
        assert!(adapter(&discovery.unwrap()).is_some_and(|(_, props)| flag(props, "Discovering")));
    }
}
