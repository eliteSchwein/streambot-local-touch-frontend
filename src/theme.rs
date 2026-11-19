use crate::{App, Theme};
use slint::{Color, ComponentHandle};
use std::{
    path::{Path, PathBuf},
    process::Command,
};

pub(crate) fn apply(app: &App, palette: &serde_json::Value) {
    let theme = app.global::<Theme>();
    let color = |key: &str, fallback: u32| {
        let value = palette[key]
            .as_str()
            .and_then(|s| u32::from_str_radix(s.trim_start_matches('#'), 16).ok())
            .unwrap_or(fallback);
        Color::from_argb_encoded(0xff000000 | value)
    };
    theme.set_background(color("background", 0x111318));
    theme.set_surface(color("surface_container", 0x1d2024));
    theme.set_elevated(color("surface_container_high", 0x282a2f));
    theme.set_raised(color("surface_container_highest", 0x33353a));
    theme.set_outline(color("outline", 0x8e9099));
    theme.set_outline_variant(color("outline_variant", 0x44474f));
    theme.set_primary(color("primary", 0xa8c7fa));
    theme.set_primary_container(color("primary_container", 0x062e6f));
    theme.set_error(color("error", 0xffb4ab));
    theme.set_on_error(color("on_error", 0x690005));
    theme.set_on_primary(color("on_primary", 0x062e6f));
    theme.set_text(color("on_surface", 0xe2e2e9));
    theme.set_muted(color("on_surface_variant", 0xc4c6d0));
}

pub(crate) fn generate(path: &Path) -> Result<serde_json::Value, String> {
    let executable = std::env::var_os("HOME")
        .map(|home| PathBuf::from(home).join(".cargo/bin/matugen"))
        .filter(|path| path.is_file())
        .unwrap_or_else(|| PathBuf::from("matugen"));
    let output = Command::new(executable)
        .args([
            "--json",
            "hex",
            "--dry-run",
            "--mode",
            "dark",
            "--source-color-index",
            "0",
            "image",
        ])
        .arg(path)
        .output()
        .map_err(|err| err.to_string())?;
    if !output.status.success() {
        return Err(String::from_utf8_lossy(&output.stderr).trim().into());
    }
    let data: serde_json::Value =
        serde_json::from_slice(&output.stdout).map_err(|err| err.to_string())?;
    dark_palette(&data)
}

fn dark_palette(data: &serde_json::Value) -> Result<serde_json::Value, String> {
    let colors = &data["colors"];
    let palette: serde_json::Map<_, _> = colors
        .get("dark")
        .unwrap_or(colors)
        .as_object()
        .into_iter()
        .flatten()
        .filter_map(|(key, value)| {
            let color = value
                .as_str()
                .or_else(|| value["color"].as_str())
                .or_else(|| value["dark"].as_str())
                .or_else(|| value["dark"]["color"].as_str())?;
            Some((key.clone(), serde_json::Value::String(color.into())))
        })
        .collect();
    if !palette.contains_key("primary") {
        return Err("palette is missing the primary color".into());
    }
    Ok(palette.into())
}

#[cfg(test)]
mod tests {
    use super::dark_palette;
    use serde_json::json;

    #[test]
    fn reads_the_dark_matugen_palette() {
        for output in [
            json!({"colors": {"primary": {"dark": {"color": "#f0a000"}}}}),
            json!({"colors": {"primary": {"dark": "#f0a000"}}}),
            json!({"colors": {"dark": {"primary": "#f0a000"}}}),
        ] {
            assert_eq!(dark_palette(&output).unwrap()["primary"], "#f0a000");
        }
    }
}
