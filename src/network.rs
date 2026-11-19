use crate::{EthernetRow, SavedWifiRow, WifiRow};
use std::{
    collections::{HashMap, HashSet},
    time::{Duration, Instant},
};
use zbus::{Connection, OwnedObjectPath, OwnedVariant, Proxy};

const SERVICE: &str = "org.freedesktop.NetworkManager";
const ROOT: &str = "/org/freedesktop/NetworkManager";
const SETTINGS_ROOT: &str = "/org/freedesktop/NetworkManager/Settings";
const MANAGER: &str = "org.freedesktop.NetworkManager";
const DEVICE: &str = "org.freedesktop.NetworkManager.Device";
const WIRELESS: &str = "org.freedesktop.NetworkManager.Device.Wireless";
const ACCESS_POINT: &str = "org.freedesktop.NetworkManager.AccessPoint";
const SETTINGS: &str = "org.freedesktop.NetworkManager.Settings";
const CONNECTION: &str = "org.freedesktop.NetworkManager.Settings.Connection";
const ACTIVE_CONNECTION: &str = "org.freedesktop.NetworkManager.Connection.Active";
const WIFI_DEVICE: u32 = 2;
const ETHERNET_DEVICE: u32 = 1;
const DEVICE_ACTIVATED: u32 = 100;
const ACTIVE_CONNECTION_ACTIVATED: u32 = 2;
const ACTIVE_CONNECTION_DEACTIVATED: u32 = 4;
const AP_FLAG_PRIVACY: u32 = 1;
const KEY_MGMT_PSK: u32 = 0x100;
const KEY_MGMT_802_1X: u32 = 0x200;
const KEY_MGMT_SAE: u32 = 0x400;
const KEY_MGMT_OWE: u32 = 0x800;
const KEY_MGMT_OWE_TM: u32 = 0x1000;
const KEY_MGMT_EAP_SUITE_B_192: u32 = 0x2000;

type ConnectionSettings = HashMap<String, HashMap<String, OwnedVariant>>;

#[derive(Default)]
pub(crate) struct NetworkManager {
    connection: Option<Connection>,
}

pub(crate) struct Snapshot {
    pub(crate) ethernet: Vec<EthernetRow>,
    pub(crate) wifi: Vec<WifiRow>,
    pub(crate) saved: Vec<SavedWifiRow>,
    pub(crate) wifi_available: bool,
    pub(crate) wifi_enabled: bool,
}

struct Profile {
    uuid: String,
    row: SavedWifiRow,
    ssid: Vec<u8>,
}

#[derive(Clone)]
struct AccessPoint {
    path: OwnedObjectPath,
    ssid: Vec<u8>,
    name: String,
    device: String,
    connected: bool,
    secured: bool,
    signal: i32,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum SecurityKind {
    Open,
    Psk,
    Sae,
    Owe,
    Wep,
}

fn setting<'a>(
    settings: &'a ConnectionSettings,
    section: &str,
    key: &str,
) -> Option<&'a OwnedVariant> {
    settings.get(section)?.get(key)
}

fn setting_text(settings: &ConnectionSettings, section: &str, key: &str) -> Option<String> {
    setting(settings, section, key)
        .and_then(|value| <&str>::try_from(value).ok())
        .map(str::to_owned)
}

fn setting_bytes(settings: &ConnectionSettings, section: &str, key: &str) -> Vec<u8> {
    setting(settings, section, key)
        .and_then(|value| Vec::<u8>::try_from(value.clone()).ok())
        .unwrap_or_default()
}

fn security_kind(flags: u32, wpa_flags: u32, rsn_flags: u32) -> Result<SecurityKind, String> {
    let key_management = wpa_flags | rsn_flags;
    if key_management & (KEY_MGMT_802_1X | KEY_MGMT_EAP_SUITE_B_192) != 0 {
        return Err("Enterprise Wi-Fi requires a saved NetworkManager profile".into());
    }
    if key_management & KEY_MGMT_SAE != 0 && key_management & KEY_MGMT_PSK == 0 {
        return Ok(SecurityKind::Sae);
    }
    if key_management & KEY_MGMT_PSK != 0 {
        return Ok(SecurityKind::Psk);
    }
    if key_management & (KEY_MGMT_OWE | KEY_MGMT_OWE_TM) != 0 {
        return Ok(SecurityKind::Owe);
    }
    if flags & AP_FLAG_PRIVACY != 0 && key_management == 0 {
        return Ok(SecurityKind::Wep);
    }
    if flags & AP_FLAG_PRIVACY == 0 && key_management == 0 {
        return Ok(SecurityKind::Open);
    }
    Err("Unsupported Wi-Fi security configuration".into())
}

fn owned_variant(value: zbus::Variant<'static>) -> OwnedVariant {
    OwnedVariant::try_from(value).expect("owned D-Bus variants are serializable")
}

fn set_setting(settings: &mut ConnectionSettings, section: &str, key: &str, value: OwnedVariant) {
    settings
        .entry(section.to_owned())
        .or_default()
        .insert(key.to_owned(), value);
}

fn wifi_connection_settings(
    ssid: &[u8],
    name: &str,
    password: &str,
    security: SecurityKind,
) -> Result<ConnectionSettings, String> {
    if matches!(
        security,
        SecurityKind::Psk | SecurityKind::Sae | SecurityKind::Wep
    ) && password.is_empty()
    {
        return Err("A Wi-Fi password is required".into());
    }

    let mut settings = ConnectionSettings::new();
    set_setting(
        &mut settings,
        "connection",
        "id",
        owned_variant(zbus::Variant::new(name.to_owned())),
    );
    set_setting(
        &mut settings,
        "connection",
        "type",
        owned_variant(zbus::Variant::new("802-11-wireless".to_owned())),
    );
    set_setting(
        &mut settings,
        "connection",
        "autoconnect",
        OwnedVariant::from(true),
    );
    set_setting(
        &mut settings,
        "802-11-wireless",
        "ssid",
        owned_variant(zbus::Variant::new(ssid.to_vec())),
    );
    set_setting(
        &mut settings,
        "802-11-wireless",
        "mode",
        owned_variant(zbus::Variant::new("infrastructure".to_owned())),
    );

    match security {
        SecurityKind::Open => {}
        SecurityKind::Psk | SecurityKind::Sae => {
            set_setting(
                &mut settings,
                "802-11-wireless-security",
                "key-mgmt",
                owned_variant(zbus::Variant::new(if security == SecurityKind::Sae {
                    "sae".to_owned()
                } else {
                    "wpa-psk".to_owned()
                })),
            );
            set_setting(
                &mut settings,
                "802-11-wireless-security",
                "psk",
                owned_variant(zbus::Variant::new(password.to_owned())),
            );
        }
        SecurityKind::Owe => set_setting(
            &mut settings,
            "802-11-wireless-security",
            "key-mgmt",
            owned_variant(zbus::Variant::new("owe".to_owned())),
        ),
        SecurityKind::Wep => {
            set_setting(
                &mut settings,
                "802-11-wireless-security",
                "key-mgmt",
                owned_variant(zbus::Variant::new("none".to_owned())),
            );
            set_setting(
                &mut settings,
                "802-11-wireless-security",
                "wep-key0",
                owned_variant(zbus::Variant::new(password.to_owned())),
            );
            set_setting(
                &mut settings,
                "802-11-wireless-security",
                "wep-key-type",
                OwnedVariant::from(2u32),
            );
        }
    }
    Ok(settings)
}

fn wifi_rows(access_points: Vec<AccessPoint>, profiles: &[Profile]) -> Vec<WifiRow> {
    let mut rows: Vec<_> = access_points
        .into_iter()
        .filter(|access_point| !access_point.ssid.is_empty())
        .map(|access_point| {
            let profile = profiles
                .iter()
                .find(|profile| profile.ssid == access_point.ssid);
            WifiRow {
                id: access_point.path.to_string().into(),
                name: access_point.name.into(),
                device: access_point.device.into(),
                secured: access_point.secured,
                connected: access_point.connected,
                signal: access_point.signal.clamp(0, 100),
                profile: profile
                    .map_or_else(String::new, |profile| profile.uuid.clone())
                    .into(),
            }
        })
        .collect();
    rows.sort_by_key(|row| (!row.connected, std::cmp::Reverse(row.signal)));
    let mut seen = HashSet::new();
    rows.retain(|row| seen.insert((row.name.clone(), row.secured)));
    rows
}

fn dbus_error(error: impl std::fmt::Display) -> String {
    error.to_string()
}

impl NetworkManager {
    async fn connection(&mut self) -> Result<&Connection, String> {
        if self.connection.is_none() {
            self.connection = Some(
                zbus::connection::Builder::system()
                    .method_timeout(Duration::from_secs(30))
                    .build()
                    .await
                    .map_err(dbus_error)?,
            );
        }
        Ok(self.connection.as_ref().unwrap())
    }

    async fn proxy<'a>(
        &'a mut self,
        path: &'a str,
        interface: &'static str,
    ) -> Result<Proxy<'a>, String> {
        Proxy::new(self.connection().await?, SERVICE, path, interface)
            .await
            .map_err(dbus_error)
    }

    async fn devices(&mut self) -> Result<Vec<OwnedObjectPath>, String> {
        self.proxy(ROOT, MANAGER)
            .await?
            .call("GetDevices", &())
            .await
            .map_err(dbus_error)
    }

    async fn profiles(
        &mut self,
        active_profiles: &HashSet<String>,
    ) -> Result<Vec<Profile>, String> {
        let paths: Vec<OwnedObjectPath> = self
            .proxy(SETTINGS_ROOT, SETTINGS)
            .await?
            .call("ListConnections", &())
            .await
            .map_err(dbus_error)?;
        let mut profiles = Vec::new();
        for path in paths {
            let connection = self.proxy(path.as_str(), CONNECTION).await?;
            let settings: ConnectionSettings = connection
                .call("GetSettings", &())
                .await
                .map_err(dbus_error)?;
            let kind = setting_text(&settings, "connection", "type");
            if kind.as_deref() != Some("802-11-wireless") {
                continue;
            }
            let Some(uuid) = setting_text(&settings, "connection", "uuid") else {
                continue;
            };
            let name = setting_text(&settings, "connection", "id").unwrap_or_default();
            let ssid = setting_bytes(&settings, "802-11-wireless", "ssid");
            profiles.push(Profile {
                row: SavedWifiRow {
                    id: uuid.clone().into(),
                    name: name.into(),
                    ssid: String::from_utf8_lossy(&ssid).into_owned().into(),
                    connected: active_profiles.contains(path.as_str()),
                },
                uuid,
                ssid,
            });
        }
        Ok(profiles)
    }

    pub(crate) async fn snapshot(&mut self, request_scan: bool) -> Result<Snapshot, String> {
        let (wireless_enabled, hardware_enabled, paths) = {
            let manager = self.proxy(ROOT, MANAGER).await?;
            let wireless_enabled = manager
                .get_property::<bool>("WirelessEnabled")
                .await
                .map_err(dbus_error)?;
            let hardware_enabled = manager
                .get_property::<bool>("WirelessHardwareEnabled")
                .await
                .map_err(dbus_error)?;
            let paths: Vec<OwnedObjectPath> =
                manager.call("GetDevices", &()).await.map_err(dbus_error)?;
            (wireless_enabled, hardware_enabled, paths)
        };

        let mut ethernet = Vec::new();
        let mut wifi_devices = Vec::new();
        let mut active_profiles = HashSet::new();
        let mut wifi_available = false;
        for path in paths {
            let device = self.proxy(path.as_str(), DEVICE).await?;
            let kind = device
                .get_property::<u32>("DeviceType")
                .await
                .map_err(dbus_error)?;
            let managed = device
                .get_property::<bool>("Managed")
                .await
                .map_err(dbus_error)?;
            let interface = device
                .get_property::<String>("Interface")
                .await
                .map_err(dbus_error)?;
            let state = device
                .get_property::<u32>("State")
                .await
                .map_err(dbus_error)?;
            if kind == WIFI_DEVICE {
                if managed {
                    wifi_available = true;
                    wifi_devices.push((path.clone(), interface.clone()));
                }
            } else if kind == ETHERNET_DEVICE && managed {
                let autoconnect = device
                    .get_property::<bool>("Autoconnect")
                    .await
                    .map_err(dbus_error)?;
                let connected = state == DEVICE_ACTIVATED;
                ethernet.push(EthernetRow {
                    id: interface.into(),
                    connected,
                    enabled: connected || autoconnect,
                });
            }
            if state == DEVICE_ACTIVATED {
                let active_path = device
                    .get_property::<OwnedObjectPath>("ActiveConnection")
                    .await
                    .map_err(dbus_error)?;
                if active_path.as_str() != "/" {
                    let active = self
                        .proxy(active_path.as_str(), ACTIVE_CONNECTION)
                        .await?
                        .get_property::<OwnedObjectPath>("Connection")
                        .await
                        .map_err(dbus_error)?;
                    active_profiles.insert(active.to_string());
                }
            }
        }
        let wifi_available = wifi_available && hardware_enabled;
        let wifi_enabled = wifi_available && wireless_enabled;
        let profiles = self.profiles(&active_profiles).await?;
        let mut access_points = Vec::new();
        if wifi_enabled {
            for (device_path, interface) in &wifi_devices {
                let (active_path, points) = {
                    let wireless = self.proxy(device_path.as_str(), WIRELESS).await?;
                    let active_path = wireless
                        .get_property::<OwnedObjectPath>("ActiveAccessPoint")
                        .await
                        .map_err(dbus_error)?;
                    if request_scan {
                        let options: HashMap<String, OwnedVariant> = HashMap::new();
                        let _ = wireless.call::<_, _, ()>("RequestScan", &options).await;
                    }
                    let points: Vec<OwnedObjectPath> = wireless
                        .call("GetAllAccessPoints", &())
                        .await
                        .map_err(dbus_error)?;
                    (active_path, points)
                };
                for path in points {
                    let point = self.proxy(path.as_str(), ACCESS_POINT).await?;
                    let ssid = point
                        .get_property::<Vec<u8>>("Ssid")
                        .await
                        .map_err(dbus_error)?;
                    let name = String::from_utf8_lossy(&ssid).into_owned();
                    let strength = point
                        .get_property::<u8>("Strength")
                        .await
                        .map_err(dbus_error)?;
                    let flags = point
                        .get_property::<u32>("Flags")
                        .await
                        .map_err(dbus_error)?;
                    let wpa_flags = point
                        .get_property::<u32>("WpaFlags")
                        .await
                        .map_err(dbus_error)?;
                    let rsn_flags = point
                        .get_property::<u32>("RsnFlags")
                        .await
                        .map_err(dbus_error)?;
                    access_points.push(AccessPoint {
                        connected: active_path == path,
                        secured: flags & AP_FLAG_PRIVACY != 0 || wpa_flags != 0 || rsn_flags != 0,
                        path,
                        ssid,
                        name,
                        device: interface.clone(),
                        signal: i32::from(strength),
                    });
                }
            }
        }
        Ok(Snapshot {
            ethernet,
            wifi: wifi_rows(access_points, &profiles),
            saved: profiles.into_iter().map(|profile| profile.row).collect(),
            wifi_available,
            wifi_enabled,
        })
    }

    async fn device(
        &mut self,
        interface: &str,
        expected_type: u32,
    ) -> Result<OwnedObjectPath, String> {
        for path in self.devices().await? {
            let device = self.proxy(path.as_str(), DEVICE).await?;
            let name = device
                .get_property::<String>("Interface")
                .await
                .map_err(dbus_error)?;
            let kind = device
                .get_property::<u32>("DeviceType")
                .await
                .map_err(dbus_error)?;
            if name == interface && kind == expected_type {
                return Ok(path);
            }
        }
        Err(format!(
            "NetworkManager device {interface} is no longer available"
        ))
    }

    async fn profile(&mut self, uuid: &str) -> Result<OwnedObjectPath, String> {
        let paths: Vec<OwnedObjectPath> = self
            .proxy(SETTINGS_ROOT, SETTINGS)
            .await?
            .call("ListConnections", &())
            .await
            .map_err(dbus_error)?;
        for path in paths {
            let proxy = self.proxy(path.as_str(), CONNECTION).await?;
            let settings: ConnectionSettings =
                proxy.call("GetSettings", &()).await.map_err(dbus_error)?;
            if setting_text(&settings, "connection", "uuid").as_deref() == Some(uuid)
                && setting_text(&settings, "connection", "type").as_deref()
                    == Some("802-11-wireless")
            {
                return Ok(path);
            }
        }
        Err("Saved Wi-Fi profile is no longer available".into())
    }

    fn root_path(&self) -> Result<OwnedObjectPath, String> {
        "/".try_into().map_err(dbus_error)
    }

    async fn activate(
        &mut self,
        profile: &OwnedObjectPath,
        device: &OwnedObjectPath,
        specific_object: &OwnedObjectPath,
    ) -> Result<(), String> {
        let active = self
            .proxy(ROOT, MANAGER)
            .await?
            .call::<_, _, OwnedObjectPath>(
                "ActivateConnection",
                &(profile, device, specific_object),
            )
            .await
            .map_err(dbus_error)?;
        self.wait_for_activation(&active).await
    }

    async fn wait_for_activation(&mut self, active: &OwnedObjectPath) -> Result<(), String> {
        let started = Instant::now();
        loop {
            let state = self
                .proxy(active.as_str(), ACTIVE_CONNECTION)
                .await?
                .get_property::<u32>("State")
                .await
                .map_err(dbus_error)?;
            match state {
                ACTIVE_CONNECTION_ACTIVATED => return Ok(()),
                ACTIVE_CONNECTION_DEACTIVATED => {
                    return Err("NetworkManager could not activate the connection".into())
                }
                _ if started.elapsed() >= Duration::from_secs(20) => {
                    return Err("NetworkManager activation timed out".into())
                }
                _ => std::thread::sleep(Duration::from_millis(250)),
            }
        }
    }

    async fn find_access_point(
        &mut self,
        id: &str,
    ) -> Result<(OwnedObjectPath, OwnedObjectPath, Vec<u8>, u32, u32, u32), String> {
        for device_path in self.devices().await? {
            let device = self.proxy(device_path.as_str(), DEVICE).await?;
            if device
                .get_property::<u32>("DeviceType")
                .await
                .map_err(dbus_error)?
                != WIFI_DEVICE
            {
                continue;
            }
            let wireless = self.proxy(device_path.as_str(), WIRELESS).await?;
            let points: Vec<OwnedObjectPath> = wireless
                .call("GetAllAccessPoints", &())
                .await
                .map_err(dbus_error)?;
            for path in points {
                if path.as_str() != id {
                    continue;
                }
                let point = self.proxy(path.as_str(), ACCESS_POINT).await?;
                let ssid = point
                    .get_property::<Vec<u8>>("Ssid")
                    .await
                    .map_err(dbus_error)?;
                let flags = point
                    .get_property::<u32>("Flags")
                    .await
                    .map_err(dbus_error)?;
                let wpa_flags = point
                    .get_property::<u32>("WpaFlags")
                    .await
                    .map_err(dbus_error)?;
                let rsn_flags = point
                    .get_property::<u32>("RsnFlags")
                    .await
                    .map_err(dbus_error)?;
                return Ok((device_path, path, ssid, flags, wpa_flags, rsn_flags));
            }
        }
        Err("Wi-Fi access point is no longer available".into())
    }

    pub(crate) async fn action(
        &mut self,
        action: &str,
        id: &str,
        password: &str,
    ) -> Result<(), String> {
        match action {
            "ethernet-on" | "ethernet-off" => {
                let path = self.device(id, ETHERNET_DEVICE).await?;
                let enabled = action == "ethernet-on";
                self.proxy(path.as_str(), DEVICE)
                    .await?
                    .set_property("Autoconnect", enabled)
                    .await
                    .map_err(dbus_error)?;
                if enabled {
                    let root = self.root_path()?;
                    self.activate(&root, &path, &root).await
                } else {
                    self.proxy(path.as_str(), DEVICE)
                        .await?
                        .call::<_, _, ()>("Disconnect", &())
                        .await
                        .map_err(dbus_error)
                }
            }
            "wifi-on" | "wifi-off" => self
                .proxy(ROOT, MANAGER)
                .await?
                .set_property("WirelessEnabled", action == "wifi-on")
                .await
                .map_err(dbus_error),
            "wifi-disconnect" => {
                let path = self.device(id, WIFI_DEVICE).await?;
                self.proxy(path.as_str(), DEVICE)
                    .await?
                    .call::<_, _, ()>("Disconnect", &())
                    .await
                    .map_err(dbus_error)
            }
            "wifi-saved" => {
                let profile = self.profile(id).await?;
                let root = self.root_path()?;
                self.activate(&profile, &root, &root).await
            }
            "wifi-forget" => {
                let profile = self.profile(id).await?;
                self.proxy(profile.as_str(), CONNECTION)
                    .await?
                    .call::<_, _, ()>("Delete", &())
                    .await
                    .map_err(dbus_error)
            }
            "wifi-connect" => {
                let (device, ap, ssid, flags, wpa_flags, rsn_flags) =
                    self.find_access_point(id).await?;
                let security = security_kind(flags, wpa_flags, rsn_flags)?;
                let name = String::from_utf8_lossy(&ssid);
                let settings = wifi_connection_settings(&ssid, &name, password, security)?;
                let (_, active) = self
                    .proxy(ROOT, MANAGER)
                    .await?
                    .call::<_, _, (OwnedObjectPath, OwnedObjectPath)>(
                        "AddAndActivateConnection",
                        &(settings, &device, &ap),
                    )
                    .await
                    .map_err(dbus_error)?;
                self.wait_for_activation(&active).await
            }
            _ => Err("Unknown device action".into()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn access_point(path: &str, ssid: &[u8], signal: i32, connected: bool) -> AccessPoint {
        AccessPoint {
            path: path.try_into().unwrap(),
            ssid: ssid.into(),
            name: String::from_utf8_lossy(ssid).into_owned(),
            device: "wlan0".into(),
            connected,
            secured: true,
            signal,
        }
    }

    #[test]
    fn wifi_rows_match_raw_ssid_and_keep_active_access_point() {
        let profile = Profile {
            uuid: "profile-uuid".into(),
            row: SavedWifiRow::default(),
            ssid: vec![b's', b't', b'u', b'd', b'i', b'o', 0xff],
        };
        let rows = wifi_rows(
            vec![
                access_point("/access/strong", b"studio", 98, false),
                access_point(
                    "/access/active",
                    &[b's', b't', b'u', b'd', b'i', b'o', 0xff],
                    61,
                    true,
                ),
                access_point("/access/guest", b"Guest", 28, false),
            ],
            &[profile],
        );
        assert_eq!(rows.len(), 3);
        assert_eq!(rows[0].id, "/access/active");
        assert_eq!(rows[0].profile, "profile-uuid");
        assert!(rows[0].connected);
        assert_eq!(rows[0].signal, 61);
        assert_eq!(rows[1].id, "/access/strong");
    }

    #[test]
    fn wifi_security_flags_produce_expected_connection_settings() {
        assert_eq!(security_kind(0, 0, 0).unwrap(), SecurityKind::Open);
        assert_eq!(security_kind(0, 0x100, 0x100).unwrap(), SecurityKind::Psk);
        assert_eq!(security_kind(0, 0x400, 0x400).unwrap(), SecurityKind::Sae);
        assert_eq!(security_kind(0, 0, 0x1000).unwrap(), SecurityKind::Owe);
        assert_eq!(
            security_kind(AP_FLAG_PRIVACY, 0, 0).unwrap(),
            SecurityKind::Wep
        );
        assert!(security_kind(0, 0x200, 0).is_err());
        assert!(security_kind(0, 0x2000, 0).is_err());

        let settings =
            wifi_connection_settings(b"office", "office", "secret", SecurityKind::Psk).unwrap();
        assert_eq!(
            setting_text(&settings, "connection", "type").as_deref(),
            Some("802-11-wireless")
        );
        assert_eq!(
            setting_text(&settings, "802-11-wireless-security", "key-mgmt").as_deref(),
            Some("wpa-psk")
        );
        assert_eq!(
            setting_text(&settings, "802-11-wireless-security", "psk").as_deref(),
            Some("secret")
        );
        assert!(wifi_connection_settings(b"office", "office", "", SecurityKind::Psk).is_err());
    }

    #[test]
    #[ignore = "requires NetworkManager on the system bus; does not request a scan"]
    fn live_snapshot_probe_reads_networkmanager_without_scanning() {
        let snapshot = zbus::block_on(NetworkManager::default().snapshot(false)).unwrap();
        assert!(snapshot.saved.iter().all(|profile| !profile.id.is_empty()));
        assert!(!snapshot.wifi_enabled || snapshot.wifi_available);
    }
}
