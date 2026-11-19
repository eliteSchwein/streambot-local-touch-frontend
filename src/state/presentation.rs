use serde_json::Value;

pub(crate) fn string_field(v: &Value, keys: &[&str]) -> String {
    keys.iter()
        .find_map(|key| v.get(*key).and_then(Value::as_str))
        .unwrap_or("")
        .to_owned()
}
pub(crate) fn time_label(v: Option<&Value>) -> String {
    let ms = v.and_then(Value::as_f64).unwrap_or(0.0).max(0.0);
    let seconds = (ms / 1000.0).floor() as u64;
    format!("{}:{:02}", seconds / 60, seconds % 60)
}

fn metric(value: &Value, paths: &[&str]) -> Option<f64> {
    paths.iter().filter_map(|p| value.pointer(p)).find_map(|v| {
        v.as_f64()
            .or_else(|| {
                let value = v.as_str()?.trim();
                value
                    .strip_suffix("°C")
                    .or_else(|| value.strip_suffix("℃"))
                    .unwrap_or(value)
                    .trim()
                    .parse()
                    .ok()
            })
            .filter(|n| n.is_finite())
    })
}

fn bytes(n: f64) -> String {
    let mut size = n;
    for unit in ["B", "KB", "MB", "GB", "TB"] {
        if size < 1024. || unit == "TB" {
            return if unit == "B" {
                format!("{size:.0} B")
            } else {
                format!("{size:.1} {unit}")
            };
        }
        size /= 1024.;
    }
    unreachable!()
}

fn unwrapped<'a>(state: &'a Value, keys: &[&str]) -> &'a Value {
    keys.iter()
        .find_map(|key| state.get(*key).filter(|v| v.is_object()))
        .unwrap_or(state)
}

pub(crate) fn storage(state: &Value) -> crate::SystemStorage {
    let raw = unwrapped(state, &["content", "storage", "info", "data"]);
    let capacity = |paths: &[&str]| metric(raw, paths).unwrap_or_default().max(0.);
    let used = capacity(&[
        "/used",
        "/usedBytes",
        "/storageUsed",
        "/disk/used",
        "/root/used",
    ]);
    let free = capacity(&[
        "/free",
        "/freeBytes",
        "/storageFree",
        "/available",
        "/disk/free",
        "/root/free",
    ]);
    let total = capacity(&[
        "/total",
        "/totalBytes",
        "/storageTotal",
        "/disk/total",
        "/root/total",
    ]);
    let fraction = |amount: f64| {
        if total > 0. {
            (amount / total).clamp(0., 1.) as f32
        } else {
            0.
        }
    };
    let folders = unwrapped(raw, &["folders", "directories", "paths"]);
    let mut categorized = 0.;
    let rows = [
        (
            "Used by Media",
            "Belegt durch Medien",
            0x2196f3,
            &["/media", "/assets"][..],
            &["/mediaUsed", "/assetUsed", "/assetsUsed"][..],
        ),
        (
            "Used by asset configs",
            "Von Asset-Konfigurationen verwendet",
            0x9c27b0,
            &["/asset_configs", "/assetConfigs"],
            &["/assetConfigUsed", "/assetConfigsUsed"],
        ),
        (
            "Used by Overlays",
            "Belegt durch Overlays",
            0x00bcd4,
            &["/overlays", "/overlay"],
            &["/overlayUsed", "/overlaysUsed"],
        ),
        (
            "Used by Music",
            "Belegt durch Musik",
            0x4caf50,
            &["/music"],
            &["/musicUsed"],
        ),
        (
            "Used by Macros",
            "Belegt durch Makros",
            0xffc107,
            &["/macros", "/macro"],
            &["/macroUsed", "/macrosUsed"],
        ),
        (
            "Used by Auto Macros",
            "Belegt durch Auto-Makros",
            0xff5722,
            &["/auto_macros", "/autoMacros", "/auto_macro"],
            &["/autoMacroUsed", "/autoMacrosUsed"],
        ),
        (
            "Used by Channel Points",
            "Belegt durch Kanalpunkte",
            0xe91e63,
            &[
                "/channel_points",
                "/channelPoints",
                "/channel_points_configs",
            ],
            &["/channelPointUsed", "/channelPointsUsed"],
        ),
        (
            "Used by Commands",
            "Belegt durch Befehle",
            0x009688,
            &["/commands", "/commands_configs"],
            &["/commands", "/commandUsed", "/commandsUsed"],
        ),
        (
            "Used by Scene rotation",
            "Belegt durch Szenenwechsel",
            0xcddc39,
            &["/rotating_scenes", "/rotatingScenes", "/rotating_scene"],
            &["/rotatingSceneUsed", "/rotatingScenesUsed"],
        ),
        (
            "Used by TTS",
            "Belegt durch TTS",
            0x673ab7,
            &["/tts"],
            &["/ttsUsed"],
        ),
        (
            "Used by Ollama",
            "Belegt durch Ollama",
            0x3f51b5,
            &["/ollama"],
            &["/ollamaUsed"],
        ),
        (
            "Used by the webcam blur",
            "Belegt durch Webcam-Unschärfe",
            0x26c6da,
            &["/webcam"],
            &[],
        ),
    ]
    .into_iter()
    .filter_map(|(label, german, color, keys, aliases)| {
        let amount = metric(folders, keys)
            .or_else(|| metric(raw, aliases))
            .filter(|n| *n > 0.)?;
        let offset = fraction(categorized);
        categorized += amount;
        Some(crate::StorageEntry {
            label: label.into(),
            german: german.into(),
            size: bytes(amount).into(),
            tint: slint::Color::from_argb_encoded(0xff000000 | color),
            fraction: fraction(amount),
            offset,
        })
    })
    .collect::<Vec<_>>();
    crate::SystemStorage {
        used: bytes(used).into(),
        free: bytes(free).into(),
        total: bytes(total).into(),
        usage: if total > 0. {
            fraction(used) * 100.
        } else {
            -1.
        },
        other: fraction((used - categorized).max(0.)),
        rows: slint::ModelRc::new(slint::VecModel::from(rows)),
    }
}

fn nested_metric(value: &Value, keys: &[&str], children: &[&str]) -> Option<f64> {
    let number = |value: &Value| {
        metric(value, &[""]).or_else(|| {
            children
                .iter()
                .find_map(|key| metric(value.get(*key)?, &[""]))
        })
    };
    match value {
        Value::Object(map) => {
            let method_value = map
                .get("method")
                .and_then(Value::as_str)
                .filter(|method| keys.contains(method))
                .and_then(|_| {
                    children
                        .iter()
                        .chain(["data", "current", "raw"].iter())
                        .filter_map(|key| map.get(*key))
                        .find_map(number)
                });
            method_value
                .or_else(|| keys.iter().filter_map(|key| map.get(*key)).find_map(number))
                .or_else(|| {
                    map.values()
                        .find_map(|child| nested_metric(child, keys, children))
                })
        }
        Value::Array(values) => values
            .iter()
            .find_map(|child| nested_metric(child, keys, children)),
        _ => None,
    }
}

pub(crate) fn system(state: &Value) -> crate::SystemStats {
    let raw = unwrapped(
        state,
        &["content", "data", "info", "system_info", "systemInfo"],
    );
    let components = raw.get("components").unwrap_or(raw);
    let read = |paths| metric(components, paths).or_else(|| metric(raw, paths));
    let percent = |value: Option<f64>| value.map_or(-1., |n| n.clamp(0., 100.) as f32);
    let load = read(&[
        "/cpu_usage",
        "/cpuUsage",
        "/cpu/usage_percent",
        "/cpu/usagePercent",
        "/cpu/load",
        "/system_cpu_usage/cpu",
    ])
    .or_else(|| {
        nested_metric(
            raw,
            &["currentLoad", "current_load", "cpuLoad", "cpu_load"],
            &[
                "currentLoad",
                "current_load",
                "value",
                "result",
                "usage_percent",
                "usagePercent",
                "usage",
                "percent",
            ],
        )
    });
    let temperature = read(&[
        "/cpu/temperature",
        "/cpu/temperature/main",
        "/cpu/temperature/max",
        "/cpu/temperature/value",
        "/cpu/temp",
        "/cpu/temp/main",
        "/cpuTempC",
        "/cpu_temperature_c",
    ])
    .or_else(|| {
        nested_metric(
            raw,
            &["cpu_temperature", "cpuTemperature", "cpuTemp", "cpu_temp"],
            &["main", "value", "result", "temperature", "temp", "max"],
        )
    });
    crate::SystemStats {
        cpu: percent(load),
        temperature: temperature.unwrap_or(-1.) as f32,
        ram: percent(read(&[
            "/ram_usage",
            "/ramUsage",
            "/memory/usage_percent",
            "/memory/usagePercent",
            "/memory/percent",
            "/memory/usage",
            "/ram/usage_percent",
            "/ram/usagePercent",
            "/ram/percent",
        ])),
        swap: percent(read(&[
            "/swap_usage",
            "/swapUsage",
            "/swap/usage_percent",
            "/swap/usagePercent",
            "/swap/percent",
            "/swap/usage",
        ])),
        has_swap: read(&["/swap/total", "/swap_total", "/swapTotal"]).is_some_and(|n| n > 0.),
        storage: percent(read(&[
            "/internal_storage_usage",
            "/internalStorageUsage",
            "/storage/internal/usage_percent",
            "/storage/internal/usagePercent",
            "/storage/internal/percent",
            "/storage/internal/usage",
        ])),
    }
}

pub(crate) fn speedtest(app: &crate::App, state: &Value) {
    let stage = state["stage"]
        .as_str()
        .filter(|stage| !stage.is_empty())
        .unwrap_or("idle");
    let running = state["running"] == true || matches!(stage, "ping" | "download" | "upload");
    app.set_speedtest_running(running && !matches!(stage, "finished" | "error" | "failed"));
    app.set_speedtest_stage(stage.into());
    let display = |key, unit, precision| {
        metric(state, &[key])
            .filter(|n| *n >= 0.)
            .map_or_else(|| "—".to_owned(), |n| format!("{n:.precision$} {unit}"))
            .into()
    };
    app.set_speedtest_ping(display("/ping_ms", "ms", 0));
    app.set_speedtest_download(display("/download_mbps", "Mbit/s", 1));
    app.set_speedtest_upload(display("/upload_mbps", "Mbit/s", 1));
    app.set_speedtest_error(string_field(state, &["error"]).into());
}

pub(crate) fn updates(state: &Value) -> slint::ModelRc<crate::UpdateEntry> {
    let managers = state.get("managers").unwrap_or(state);
    let mut rows = managers
        .as_object()
        .into_iter()
        .flatten()
        .filter(|(_, v)| v.is_object())
        .map(|(name, v)| {
            let packages = v["updates"]
                .as_array()
                .map(Vec::as_slice)
                .unwrap_or_default();
            let count = metric(
                v,
                &[
                    "/package_count",
                    "/packageCount",
                    "/packages_count",
                    "/packagesCount",
                    "/update_count",
                    "/updateCount",
                    "/updates_count",
                    "/updatesCount",
                    "/count",
                ],
            )
            .unwrap_or_default()
            .max(packages.len() as f64) as i32;
            let available = v["update_available"] == true || count > 0;
            let checking = v["checking"] == true;
            let updating = v["updating"] == true;
            let details = &v["progress"];
            let mut preview = packages
                .iter()
                .take(3)
                .filter_map(|p| p["package"].as_str())
                .collect::<Vec<_>>()
                .join(", ");
            if packages.len() > 3 {
                preview.push_str(&format!(" +{}", packages.len() - 3));
            }
            let current = string_field(v, &["current_version", "commit"]);
            let latest = string_field(v, &["latest_version", "latest_commit"]);
            let version = if current.is_empty() {
                "—".into()
            } else if available && !latest.is_empty() && current != latest {
                format!("{current} → {latest}")
            } else {
                current
            };
            let mut package = string_field(details, &["package"]);
            if let (Some(index), Some(total)) = (
                metric(details, &["/package_index"]),
                metric(details, &["/package_total"]),
            ) {
                if !package.is_empty() && index > 0. && total > 0. {
                    package.push_str(&format!(" ({index}/{total})"));
                }
            }
            let progress = |key| metric(details, &[key]).map_or(-1., |n| n.clamp(0., 100.) as f32);
            crate::UpdateEntry {
                id: name.as_str().into(),
                git: v["type"] == "git",
                available,
                active: available && !checking && !updating,
                busy: checking || updating,
                updating,
                checking,
                version: version.into(),
                count,
                preview: preview.into(),
                error: string_field(v, &["error"]).into(),
                stage: string_field(details, &["stage"]).into(),
                message: string_field(details, &["message"]).into(),
                progress: progress("/percent"),
                package: package.into(),
                package_progress: progress("/package_percent"),
            }
        })
        .collect::<Vec<_>>();
    rows.sort_by_key(|r| (r.id == "system", r.id.to_lowercase()));
    slint::ModelRc::new(slint::VecModel::from(rows))
}
#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    #[test]
    fn system_handles_method_wrapped_cpu_samples() {
        let stats = system(&json!({"content":{"components":{"samples":[
            {"method":"currentLoad","data":{"currentLoad":"65"}},
            {"method":"cpuTemperature","result":{"main":"46 °C"}}
        ]}}}));
        assert_eq!(stats.cpu, 65.);
        assert_eq!(stats.temperature, 46.);
    }

    #[test]
    fn storage_includes_video_models_and_wrapped_capacity() {
        let result = storage(&json!({"data":{"disk":{"total":2048},"folders":{"webcam":1024}}}));
        use slint::Model;
        assert_eq!(result.total, "2.0 KB");
        let webcam = result.rows.row_data(0).unwrap();
        assert_eq!(webcam.size, "1.0 KB");
        assert_eq!(webcam.fraction, 0.5);
    }
}
