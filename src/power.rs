use crate::{ui_bridge::ui_event, App};
use slint::{ComponentHandle, Model, ModelRc, SharedString, VecModel};
use std::{collections::HashMap, time::Duration};
use tokio::{
    runtime::Handle,
    sync::{mpsc, watch},
    time::{self, MissedTickBehavior},
};
use zbus::{
    proxy::{Builder, CacheProperties},
    Connection, OwnedVariant, Proxy,
};

const PROFILE_SERVICES: [(&str, &str); 2] = [
    (
        "org.freedesktop.UPower.PowerProfiles",
        "/org/freedesktop/UPower/PowerProfiles",
    ),
    ("net.hadess.PowerProfiles", "/net/hadess/PowerProfiles"),
];

mod battery;

#[derive(Default)]
struct Profiles {
    available: Vec<String>,
    active: String,
}

pub(crate) fn install(app: &App, runtime: &Handle) {
    let (commands, mut requests) = mpsc::channel::<String>(1);
    let (visibility, mut details_open) = watch::channel(app.get_power_details_open());
    battery::install(app, details_open.clone());
    app.on_power_details_visibility(move |visible| {
        let _ = visibility.send(visible);
    });
    let weak = app.as_weak();
    app.on_choose_power_profile(move |profile| {
        let Some(app) = weak.upgrade() else { return };
        if app.get_power_profile_busy()
            || profile == app.get_active_power_profile()
            || !app.get_power_profiles().iter().any(|item| item == profile)
        {
            return;
        }
        if commands.try_send(profile.to_string()).is_ok() {
            app.set_power_profile_failed(false);
            app.set_power_profile_error("".into());
            app.set_power_profile_busy(true);
        }
    });

    let weak = app.as_weak();
    runtime.spawn(async move {
        let mut connection: Option<Connection> = None;
        let mut poll = time::interval(Duration::from_secs(5));
        poll.set_missed_tick_behavior(MissedTickBehavior::Skip);
        loop {
            let requested = tokio::select! {
                request = requests.recv() => match request {
                    Some(request) => Some(request),
                    None => break,
                },
                visibility = details_open.changed() => {
                    if visibility.is_err() { break; }
                    None
                },
                _ = poll.tick() => None,
            };
            if connection.as_ref().is_none_or(Connection::is_closed) {
                connection = zbus::connection::Builder::system()
                    .method_timeout(Duration::from_secs(3))
                    .build()
                    .await
                    .ok();
            }
            let (profiles, error) = power_profiles(connection.as_ref(), requested.as_deref()).await;
            let changed_profile = requested.is_some();
            ui_event(&weak, move |app| {
                let current = app.get_power_profiles();
                if current.row_count() != profiles.available.len()
                    || current
                        .iter()
                        .zip(&profiles.available)
                        .any(|(current, available)| current.as_str() != available)
                {
                    let model = profiles
                        .available
                        .into_iter()
                        .map(SharedString::from)
                        .collect::<Vec<_>>();
                    app.set_power_profiles(ModelRc::new(VecModel::from(model)));
                }
                app.set_active_power_profile(profiles.active.into());
                if changed_profile {
                    app.set_power_profile_busy(false);
                    app.set_power_profile_failed(error.is_some());
                    app.set_power_profile_error(error.unwrap_or_default().into());
                }
            });
        }
    });
}

async fn proxy<'a>(
    connection: &Connection,
    service: &'a str,
    path: &'a str,
    interface: &'a str,
) -> zbus::Result<Proxy<'a>> {
    Builder::new(connection)
        .destination(service)
        .path(path)
        .interface(interface)
        .cache_properties(CacheProperties::No)
        .build()
        .await
}

async fn power_profiles(
    connection: Option<&Connection>,
    requested: Option<&str>,
) -> (Profiles, Option<String>) {
    if let Some(connection) = connection {
        for (service, path) in PROFILE_SERVICES {
            let Ok(proxy) = proxy(connection, service, path, service).await else {
                continue;
            };
            let Ok(records) = proxy
                .get_property::<Vec<HashMap<String, OwnedVariant>>>("Profiles")
                .await
            else {
                continue;
            };
            let available: Vec<String> = records
                .iter()
                .filter_map(|profile| {
                    <&str>::try_from(profile.get("Profile")?)
                        .ok()
                        .map(str::to_owned)
                })
                .collect();
            let error = match requested {
                Some(profile) if available.iter().any(|item| item == profile) => proxy
                    .set_property("ActiveProfile", profile)
                    .await
                    .err()
                    .map(|error| error.to_string()),
                Some(_) => Some(String::new()),
                None => None,
            };
            let active = proxy
                .get_property("ActiveProfile")
                .await
                .unwrap_or_default();
            return (Profiles { available, active }, error);
        }
    }
    (Profiles::default(), requested.map(|_| String::new()))
}

#[cfg(test)]
mod tests {
    use super::*;

    struct MockProfiles(String);

    #[zbus::interface(name = "net.hadess.PowerProfiles")]
    impl MockProfiles {
        #[zbus(property)]
        fn profiles(&self) -> Vec<HashMap<String, OwnedVariant>> {
            ["power-saver", "balanced"]
                .into_iter()
                .map(|profile| {
                    HashMap::from([(
                        "Profile".into(),
                        zbus::Variant::from(profile).try_into().unwrap(),
                    )])
                })
                .collect()
        }

        #[zbus(property)]
        fn active_profile(&self) -> &str {
            &self.0
        }

        #[zbus(property)]
        fn set_active_profile(&mut self, profile: String) {
            self.0 = profile;
        }
    }

    #[tokio::test]
    #[ignore = "run in an isolated D-Bus session with dbus-run-session"]
    async fn switches_a_profile_using_the_legacy_dbus_api() {
        let (service, path) = PROFILE_SERVICES[1];
        let _mock = zbus::connection::Builder::session()
            .serve_at(path, MockProfiles("balanced".into()))
            .name(service)
            .build()
            .await
            .unwrap();
        let client = Connection::session().await.unwrap();
        let (state, error) = power_profiles(Some(&client), Some("power-saver")).await;
        assert_eq!(state.available, ["power-saver", "balanced"]);
        assert_eq!(state.active, "power-saver");
        assert!(error.is_none());
        let (state, error) = power_profiles(Some(&client), Some("performance")).await;
        assert_eq!(state.active, "power-saver");
        assert!(error.is_some());
    }
}
