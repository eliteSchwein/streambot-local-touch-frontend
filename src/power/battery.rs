use super::proxy;
use std::{
    collections::{HashMap, VecDeque},
    fs,
    path::Path,
    time::{Duration, Instant, SystemTime, UNIX_EPOCH},
};
use zbus::{Connection, OwnedObjectPath};

const UPOWER: &str = "org.freedesktop.UPower";
const DEVICE: &str = "org.freedesktop.UPower.Device";
const HISTORY_HOURS: usize = 24;
const SECONDS_PER_HOUR: u64 = 3600;
const HISTORY_SECONDS: u64 = HISTORY_HOURS as u64 * SECONDS_PER_HOUR;

#[derive(Clone, Copy)]
pub(super) struct Battery {
    pub percent: i32,
    pub state: u32,
    pub seconds_remaining: i64,
    pub watts: f32,
    pub capacity: Capacity,
}

#[derive(Clone, Copy, Default)]
pub(super) struct Capacity {
    pub full: f64,
    pub design: f64,
    pub unit: &'static str,
}

impl Capacity {
    fn complete(self) -> bool {
        self.full > 0.0 && self.design > 0.0
    }

    fn with_fallback(self, fallback: Self) -> Self {
        if self.unit == fallback.unit {
            return Self {
                full: if self.full > 0.0 {
                    self.full
                } else {
                    fallback.full
                },
                design: if self.design > 0.0 {
                    self.design
                } else {
                    fallback.design
                },
                unit: self.unit,
            };
        }
        if !self.complete() && (fallback.complete() || (self.full == 0.0 && self.design == 0.0)) {
            return fallback;
        }
        self
    }

    pub(super) fn health(self) -> i32 {
        if self.complete() {
            (self.full / self.design * 100.0).round().clamp(0.0, 100.0) as i32
        } else {
            -1
        }
    }
}

pub(super) async fn status(connection: Option<&Connection>) -> Option<Battery> {
    let sysfs = Path::new("/sys/class/power_supply");
    if let Some(connection) = connection {
        if let Some(mut battery) = upower_battery(connection).await {
            if !battery.capacity.complete() {
                if let Some(fallback) = sysfs_battery(sysfs) {
                    battery.capacity = battery.capacity.with_fallback(fallback.capacity);
                }
            }
            return Some(battery);
        }
    }
    sysfs_battery(sysfs)
}

async fn upower_battery(connection: &Connection) -> Option<Battery> {
    let proxy = proxy(
        connection,
        UPOWER,
        "/org/freedesktop/UPower/devices/DisplayDevice",
        DEVICE,
    )
    .await
    .ok()?;
    let (present, percentage, state) = tokio::try_join!(
        proxy.get_property::<bool>("IsPresent"),
        proxy.get_property::<f64>("Percentage"),
        proxy.get_property::<u32>("State"),
    )
    .ok()?;
    if !present || !(0.0..=100.0).contains(&percentage) {
        return None;
    }
    let (seconds_remaining, rate, full, design) = tokio::join!(
        async {
            match state {
                1 => proxy.get_property::<i64>("TimeToFull").await.unwrap_or(0),
                2 => proxy.get_property::<i64>("TimeToEmpty").await.unwrap_or(0),
                _ => 0,
            }
        },
        proxy.get_property::<f64>("EnergyRate"),
        proxy.get_property::<f64>("EnergyFull"),
        proxy.get_property::<f64>("EnergyFullDesign"),
    );
    let capacity_value = |value: zbus::Result<f64>| {
        value
            .ok()
            .filter(|value| value.is_finite() && *value > 0.0)
            .unwrap_or(0.0)
    };
    Some(Battery {
        percent: percentage.round() as i32,
        state,
        seconds_remaining,
        watts: rate
            .ok()
            .filter(|rate| rate.is_finite())
            .map_or(-1.0, |rate| rate.abs() as f32),
        capacity: Capacity {
            full: capacity_value(full),
            design: capacity_value(design),
            unit: "Wh",
        },
    })
}

fn sysfs_battery(path: &Path) -> Option<Battery> {
    let mut percentages = Vec::new();
    let mut energies = Vec::new();
    let mut capacities = Vec::new();
    let mut state = 0;
    let mut seconds_remaining = 0;
    let mut watts = -1.0;
    for entry in fs::read_dir(path).ok()?.flatten() {
        let Ok(data) = fs::read_to_string(entry.path().join("uevent")) else {
            continue;
        };
        let fields: HashMap<&str, &str> = data
            .lines()
            .filter_map(|line| line.split_once('='))
            .collect();
        if fields.get("POWER_SUPPLY_TYPE") != Some(&"Battery")
            || fields.get("POWER_SUPPLY_SCOPE") == Some(&"Device")
            || fields.get("POWER_SUPPLY_PRESENT") == Some(&"0")
        {
            continue;
        }
        let number = |key| fields.get(key).and_then(|value| value.parse::<u64>().ok());
        let scaled = |key, divisor| number(key).unwrap_or(0) as f64 / divisor;
        capacities.push(
            Capacity {
                full: scaled("POWER_SUPPLY_ENERGY_FULL", 1_000_000.0),
                design: scaled("POWER_SUPPLY_ENERGY_FULL_DESIGN", 1_000_000.0),
                unit: "Wh",
            }
            .with_fallback(Capacity {
                full: scaled("POWER_SUPPLY_CHARGE_FULL", 1_000.0),
                design: scaled("POWER_SUPPLY_CHARGE_FULL_DESIGN", 1_000.0),
                unit: "mAh",
            }),
        );
        let Some(percent) = fields
            .get("POWER_SUPPLY_CAPACITY")
            .and_then(|value| value.parse::<u32>().ok())
            .filter(|value| *value <= 100)
        else {
            continue;
        };
        percentages.push(f64::from(percent));
        let pack_state = match fields.get("POWER_SUPPLY_STATUS").copied() {
            Some("Charging") => 1,
            Some("Discharging") => 2,
            Some("Full") => 4,
            Some("Not charging") => 5,
            _ => 0,
        };
        if state != 1 && (state != 2 || pack_state == 1) && pack_state != 0 {
            state = pack_state;
        }
        let energy = number("POWER_SUPPLY_ENERGY_NOW")
            .zip(number("POWER_SUPPLY_ENERGY_FULL"))
            .filter(|(_, full)| *full > 0);
        if let Some(energy) = energy {
            energies.push(energy);
        }
        let power = number("POWER_SUPPLY_POWER_NOW").filter(|watts| *watts > 0);
        watts = power.map_or(-1.0, |microwatts| microwatts as f32 / 1_000_000.0);
        let time_key = match pack_state {
            1 => Some("POWER_SUPPLY_TIME_TO_FULL_NOW"),
            2 => Some("POWER_SUPPLY_TIME_TO_EMPTY_NOW"),
            _ => None,
        };
        seconds_remaining = time_key
            .and_then(|key| {
                number(key).filter(|seconds| *seconds > 0).or_else(|| {
                    let ((now, full), power) = energy.zip(power)?;
                    let remaining = if pack_state == 1 {
                        full.saturating_sub(now)
                    } else {
                        now
                    };
                    Some(remaining.saturating_mul(SECONDS_PER_HOUR) / power)
                })
            })
            .and_then(|seconds| i64::try_from(seconds).ok())
            .unwrap_or(0);
    }
    if percentages.is_empty() {
        return None;
    }
    let percent = if percentages.len() == energies.len() {
        let (now, full) = energies
            .into_iter()
            .fold((0.0, 0.0), |(now, full), battery| {
                (now + battery.0 as f64, full + battery.1 as f64)
            });
        now / full * 100.0
    } else {
        percentages.iter().sum::<f64>() / percentages.len() as f64
    };
    Some(Battery {
        percent: percent.clamp(0.0, 100.0).round() as i32,
        state,
        seconds_remaining: if percentages.len() == 1 {
            seconds_remaining
        } else {
            0
        },
        watts: if percentages.len() == 1 { watts } else { -1.0 },
        capacity: combined_capacity(&capacities),
    })
}

fn combined_capacity(packs: &[Capacity]) -> Capacity {
    let Some(first) = packs.first() else {
        return Capacity::default();
    };
    if packs.iter().any(|pack| pack.unit != first.unit) {
        return Capacity::default();
    }
    Capacity {
        full: if packs.iter().all(|pack| pack.full > 0.0) {
            packs.iter().map(|pack| pack.full).sum()
        } else {
            0.0
        },
        design: if packs.iter().all(|pack| pack.design > 0.0) {
            packs.iter().map(|pack| pack.design).sum()
        } else {
            0.0
        },
        unit: first.unit,
    }
}

#[derive(Default)]
pub(super) struct History {
    sampled: VecDeque<(u64, f32)>,
    saved: Vec<(u64, f32)>,
    last_fetch: Option<Instant>,
}

impl History {
    pub(super) async fn update(
        &mut self,
        connection: Option<&Connection>,
        battery: Option<Battery>,
        visible: bool,
    ) -> Option<Vec<f32>> {
        let now = SystemTime::now().duration_since(UNIX_EPOCH).ok()?.as_secs();
        self.sampled
            .retain(|&(timestamp, _)| timestamp <= now && now - timestamp < HISTORY_SECONDS);
        let latest = battery.map(|battery| (now, battery.percent as f32));
        if let Some(sample) = latest {
            if self
                .sampled
                .back()
                .is_none_or(|&(time, _)| now - time >= 60)
            {
                self.sampled.push_back(sample);
            }
        }
        if !visible {
            return None;
        }
        if self
            .last_fetch
            .is_none_or(|time| time.elapsed() >= Duration::from_secs(60))
        {
            self.last_fetch = Some(Instant::now());
            if let Some(connection) = connection.filter(|_| battery.is_some()) {
                if let Ok(Some(saved)) =
                    tokio::time::timeout(Duration::from_secs(3), upower_history(connection)).await
                {
                    self.saved = saved;
                }
            }
        }
        Some(hourly_samples(
            now,
            self.saved
                .iter()
                .chain(&self.sampled)
                .copied()
                .chain(latest),
        ))
    }
}

async fn upower_history(connection: &Connection) -> Option<Vec<(u64, f32)>> {
    let root = proxy(connection, UPOWER, "/org/freedesktop/UPower", UPOWER)
        .await
        .ok()?;
    let devices: Vec<OwnedObjectPath> = root.call("EnumerateDevices", &()).await.ok()?;
    let mut battery_path = None;
    for path in &devices {
        let device = proxy(connection, UPOWER, path.as_str(), DEVICE)
            .await
            .ok()?;
        if device.get_property::<u32>("Type").await.ok() != Some(2)
            || device.get_property::<bool>("PowerSupply").await.ok() != Some(true)
            || device.get_property::<bool>("IsPresent").await.ok() != Some(true)
        {
            continue;
        }
        // Per-pack history cannot represent a multi-battery system's combined percentage.
        if battery_path.replace(path).is_some() {
            return Some(Vec::new());
        }
    }
    let Some(path) = battery_path else {
        return Some(Vec::new());
    };
    let device = proxy(connection, UPOWER, path.as_str(), DEVICE)
        .await
        .ok()?;
    if !device.get_property::<bool>("HasHistory").await.ok()? {
        return Some(Vec::new());
    }
    let history: Vec<(u32, f64, u32)> = device
        .call("GetHistory", &("charge", HISTORY_SECONDS as u32, 240u32))
        .await
        .ok()?;
    Some(
        history
            .into_iter()
            .filter(|&(_, charge, state)| state != 0 && (0.0..=100.0).contains(&charge))
            .map(|(timestamp, charge, _)| (u64::from(timestamp), charge as f32))
            .collect(),
    )
}

fn hourly_samples(now: u64, samples: impl IntoIterator<Item = (u64, f32)>) -> Vec<f32> {
    let mut buckets = [None; HISTORY_HOURS];
    for (time, charge) in samples {
        let Some(age) = now.checked_sub(time) else {
            continue;
        };
        let index = HISTORY_HOURS.checked_sub(1 + (age / SECONDS_PER_HOUR) as usize);
        if let Some(bucket) = index.map(|index| &mut buckets[index]) {
            if bucket.is_none_or(|(previous, _)| time >= previous) {
                *bucket = Some((time, charge));
            }
        }
    }
    buckets
        .into_iter()
        .map(|sample| sample.map_or(-1.0, |(_, charge)| charge))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn battery_uses_internal_packs_and_ignores_peripherals() {
        let root =
            std::env::temp_dir().join(format!("streambot-battery-test-{}", std::process::id()));
        fs::create_dir(&root).unwrap();
        for (name, properties) in [
            ("mouse", "SCOPE=Device\nCAPACITY=10"),
            ("absent", "PRESENT=0\nCAPACITY=0"),
            (
                "BAT0",
                "PRESENT=1\nCAPACITY=50\nENERGY_NOW=10000000\nENERGY_FULL=20000000\nENERGY_FULL_DESIGN=25000000",
            ),
            (
                "BAT1",
                "STATUS=Charging\nCAPACITY=75\nENERGY_NOW=60000000\nENERGY_FULL=80000000\nENERGY_FULL_DESIGN=100000000\nPOWER_NOW=10000000",
            ),
        ] {
            let device = root.join(name);
            fs::create_dir(&device).unwrap();
            let data = format!("TYPE=Battery\n{properties}")
                .lines()
                .map(|line| format!("POWER_SUPPLY_{line}\n"))
                .collect::<String>();
            fs::write(device.join("uevent"), data).unwrap();
        }
        let battery = sysfs_battery(&root).unwrap();
        fs::remove_dir_all(root.join("BAT0")).unwrap();
        let single = sysfs_battery(&root).unwrap();
        fs::write(
            root.join("BAT1/uevent"),
            "POWER_SUPPLY_TYPE=Battery\nPOWER_SUPPLY_CAPACITY=75\nPOWER_SUPPLY_CHARGE_FULL=3800000\nPOWER_SUPPLY_CHARGE_FULL_DESIGN=4000000\n",
        )
        .unwrap();
        let charge_only = sysfs_battery(&root).unwrap();
        fs::remove_dir_all(root).unwrap();
        assert_eq!(battery.percent, 70);
        assert_eq!(battery.state, 1);
        assert_eq!(battery.seconds_remaining, 0);
        assert_eq!(battery.capacity.unit, "Wh");
        assert_eq!(battery.capacity.full, 100.0);
        assert_eq!(battery.capacity.design, 125.0);
        assert_eq!(battery.capacity.health(), 80);
        assert_eq!(single.percent, 75);
        assert_eq!(single.seconds_remaining, 7200);
        assert_eq!(charge_only.capacity.unit, "mAh");
        assert_eq!(charge_only.capacity.full, 3800.0);
        assert_eq!(charge_only.capacity.design, 4000.0);
        assert_eq!(charge_only.capacity.health(), 95);
        assert_eq!(Capacity::default().health(), -1);
    }

    #[test]
    fn history_keeps_the_latest_sample_per_hour_and_preserves_gaps() {
        let now = HISTORY_SECONDS * 2;
        let history = hourly_samples(
            now,
            [
                (now - 3601, 68.0),
                (now - 7000, 75.0),
                (now - 20, 62.0),
                (now + 60, 100.0),
                (now - HISTORY_SECONDS, 100.0),
            ],
        );
        assert!(history[..22].iter().all(|&percent| percent == -1.0));
        assert_eq!(history[22..], [68.0, 62.0]);
    }
}
