mod network;
mod settings;

use tauri::{AppHandle, Manager, PhysicalSize, Size};
use tauri_plugin_cli::CliExt;

#[tauri::command]
fn frontend_log(level: String, message: String) {
    match level.as_str() {
        "error" => eprintln!("[frontend:error] {message}"),
        "warn" => eprintln!("[frontend:warn] {message}"),
        "log" => println!("[frontend:log] {message}"),
        _ => println!("[frontend:{level}] {message}"),
    }
}


#[tauri::command]
fn wake_main_window(app: AppHandle) -> Result<(), String> {
    let window = app
        .get_webview_window("main")
        .ok_or_else(|| "main window not found".to_string())?;

    let _ = window.unminimize();
    window.show().map_err(|error| error.to_string())?;
    window.set_focus().map_err(|error| error.to_string())?;

    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_cli::init())
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            frontend_log,
            wake_main_window,

            settings::get_streambot_settings,
            settings::set_streambot_language,

            network::get_network_status,
            network::get_wifi_settings,
            network::get_wired_settings,
            network::get_canbus_settings,
            network::set_wifi_enabled,
            network::set_wired_interface_enabled,
            network::scan_wifi_networks,
            network::connect_to_wifi,
            network::connect_hidden_wifi,
            network::forget_saved_wifi,
            network::get_primary_ip_address,
        ])
        .setup(|app| {
            let matches = app.cli().matches().ok();

            let fullscreen = matches
                .as_ref()
                .and_then(|m| m.args.get("fullscreen"))
                .and_then(|arg| arg.value.as_bool())
                .unwrap_or(false);

            if fullscreen {
                if let Some(window) = app.get_webview_window("main") {
                    if let Ok(Some(monitor)) = window.current_monitor() {
                        let size = monitor.size();

                        let _ = window.set_fullscreen(true);
                        let _ = window.set_decorations(false);
                        let _ = window.set_resizable(false);
                        let _ = window.set_size(Size::Physical(PhysicalSize {
                            width: size.width,
                            height: size.height,
                        }));
                        let _ = window.set_focus();
                    }
                }
            }

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}