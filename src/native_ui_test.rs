use super::*;
use serde_json::json;
use slint::platform::{software_renderer::MinimalSoftwareWindow, Platform, WindowAdapter};
use slint::platform::{Key, PointerEventButton, WindowEvent};
use slint::winit_030::{
    winit::{
        event::ElementState,
        keyboard::{KeyCode, ModifiersState, PhysicalKey},
    },
    EventResult,
};
use slint::{LogicalPosition, Model, ModelRc, PhysicalSize, PlatformError, Rgb8Pixel, VecModel};
use std::cell::Cell;
use std::rc::Rc;
use std::time::Instant;

struct TestDisplay {
    window: Rc<MinimalSoftwareWindow>,
    started: Instant,
    elapsed_offset: Rc<Cell<Duration>>,
}

impl Platform for TestDisplay {
    fn create_window_adapter(&self) -> Result<Rc<dyn WindowAdapter>, PlatformError> {
        Ok(self.window.clone())
    }

    fn duration_since_start(&self) -> Duration {
        self.started.elapsed() + self.elapsed_offset.get()
    }
}

#[test]
fn startup_animation_reveals_navigation_when_the_connection_overlay_closes() {
    let window = MinimalSoftwareWindow::new(Default::default());
    let elapsed_offset = Rc::new(Cell::new(Duration::ZERO));
    slint::platform::set_platform(Box::new(TestDisplay {
        window: window.clone(),
        started: Instant::now(),
        elapsed_offset: elapsed_offset.clone(),
    }))
    .unwrap();
    let app = App::new().unwrap();
    app.show().unwrap();
    window.set_size(PhysicalSize::new(800, 480));
    let active_pill = Rgb8Pixel {
        r: 0xa8,
        g: 0xc7,
        b: 0xfa,
    };
    let mut buffer = vec![Rgb8Pixel::default(); 800 * 480];
    let mut render = |advance_ms| {
        elapsed_offset.set(elapsed_offset.get() + Duration::from_millis(advance_ms));
        slint::platform::update_timers_and_animations();
        window.draw_if_needed(|r| {
            r.render(&mut buffer, 800);
        });
        let progress_width = buffer[..428 * 800]
            .chunks_exact(800)
            .map(|row| {
                row[260..540]
                    .iter()
                    .filter(|&&pixel| pixel == active_pill)
                    .count()
            })
            .max()
            .unwrap();
        (buffer[440 * 800 + 221], progress_width)
    };

    app.invoke_enable_gpu_effects();
    assert_eq!(render(0), (active_pill, 0));
    backend::apply_startup_status(&app, "Loading cache", false);
    let (boot_nav, early_width) = render(0);
    assert_eq!(boot_nav, active_pill, "navigation is visible during boot");
    assert!(early_width > 0);
    assert_eq!(render(600).1, early_width, "time alone adds no progress");

    backend::apply_startup_status(&app, "starting_audio", false);
    let middle_width = render(0).1;
    assert!(middle_width > early_width);
    backend::apply_startup_status(&app, "unknown-stage", false);
    assert_eq!(render(0).1, middle_width);
    backend::apply_startup_status(&app, "loading_cache", false);
    assert_eq!(
        render(0).1,
        middle_width,
        "older stages do not move the bar backward"
    );

    backend::apply_startup_status(&app, "updating_event_index", false);
    assert!(render(0).1 > middle_width);
    backend::apply_startup_status(&app, "finished", true);
    assert_eq!(app.get_backend_progress(), 1.0);
    app.set_connection("Connecting…".into());
    assert_eq!(render(2000), (active_pill, 0));

    app.set_connection("Connected".into());
    let first_frame = render(0).0;
    assert_ne!(first_frame, active_pill, "the reveal starts on connection");
    assert_eq!(render(1200).0, active_pill);

    app.set_connection("Disconnected — retrying".into());
    assert_eq!(
        render(0),
        (active_pill, 0),
        "navigation stays available offline and the boot indicator is gone"
    );
    app.set_connection("Connected".into());
    assert_eq!(render(0).0, first_frame, "the reveal restarts on reconnect");
    assert_eq!(render(1200).0, active_pill);

    app.set_connection("Backend not ready".into());
    backend::apply_startup_status(&app, "loading_cache", false);
    assert_eq!(render(0).1, early_width, "a new boot starts a fresh bar");
}

#[test]
fn page_buttons_stay_centered_with_battery_and_edit_controls() {
    let window = MinimalSoftwareWindow::new(Default::default());
    slint::platform::set_platform(Box::new(TestDisplay {
        window: window.clone(),
        started: Instant::now(),
        elapsed_offset: Rc::new(Cell::new(Duration::ZERO)),
    }))
    .unwrap();
    let app = App::new().unwrap();
    app.show().unwrap();
    window.set_size(PhysicalSize::new(700, 450));
    app.set_connection("Connected".into());
    app.set_battery_percent(68);
    app.set_dev_page_enabled(true);

    let mut buffer = vec![Rgb8Pixel::default(); 700 * 450];
    let primary = Rgb8Pixel {
        r: 0xa8,
        g: 0xc7,
        b: 0xfa,
    };
    let mut pill_bounds = || {
        window.draw_if_needed(|r| {
            r.render(&mut buffer, 700);
        });
        let row = &buffer[410 * 700..411 * 700];
        let left = row.iter().position(|&pixel| pixel == primary).unwrap();
        let right = row.iter().rposition(|&pixel| pixel == primary).unwrap();
        (left, right)
    };
    let (home_left, _) = pill_bounds();
    assert!(home_left >= 134, "Home clears the edit button");
    app.set_page(5);
    let (_, dev_right) = pill_bounds();
    assert!(
        (home_left + dev_right).abs_diff(699) <= 1,
        "the page buttons are centered"
    );
    app.set_page(0);

    for event in [
        WindowEvent::PointerPressed {
            position: LogicalPosition::new(114., 424.),
            button: PointerEventButton::Left,
        },
        WindowEvent::PointerReleased {
            position: LogicalPosition::new(114., 424.),
            button: PointerEventButton::Left,
        },
    ] {
        app.window().dispatch_event(event);
    }
    assert!(
        app.get_dashboard_editing(),
        "the edit button sits beside the battery"
    );
    assert!(!app.get_power_details_open());
}

#[test]
fn dashboard_playback_controls_share_a_center_line() {
    let window = MinimalSoftwareWindow::new(Default::default());
    slint::platform::set_platform(Box::new(TestDisplay {
        window: window.clone(),
        started: Instant::now(),
        elapsed_offset: Rc::new(Cell::new(Duration::ZERO)),
    }))
    .unwrap();
    let app = App::new().unwrap();
    app.show().unwrap();
    window.set_size(PhysicalSize::new(800, 480));
    app.set_connection("Connected".into());
    app.set_cava_bars(ModelRc::default());
    app.set_music_shuffle(true);
    app.set_music_loop(true);
    let (action_tx, action_rx) = std::sync::mpsc::channel();
    app.on_music_action(move |action| action_tx.send(action).unwrap());

    let primary = Rgb8Pixel {
        r: 0xa8,
        g: 0xc7,
        b: 0xfa,
    };
    let icon_color = Rgb8Pixel {
        r: 0x06,
        g: 0x2e,
        b: 0x6f,
    };
    let mut buffer = vec![Rgb8Pixel::default(); 800 * 480];
    for lower_slot in ["", "interactions"] {
        app.set_right_slot_1(lower_slot.into());
        for (playing, expected_action) in [(false, "play"), (true, "pause")] {
            app.set_music_playing(playing);
            window.draw_if_needed(|r| {
                r.render(&mut buffer, 800);
            });
            let center_y = |columns: std::ops::Range<usize>, color| {
                let mut rows = buffer[..428 * 800]
                    .chunks_exact(800)
                    .enumerate()
                    .filter(|(_, row)| row[columns.clone()].contains(&color))
                    .map(|(y, _)| y);
                let top = rows.next().unwrap();
                let bottom = rows.last().unwrap_or(top);
                (top + bottom) / 2
            };
            let center = center_y(549..646, primary);
            assert!(center.abs_diff(center_y(423..499, primary)) <= 1);
            assert!(center.abs_diff(center_y(696..775, primary)) <= 1);
            assert!(center.abs_diff(center_y(549..646, icon_color)) <= 1);

            let position = LogicalPosition::new(597., center as f32);
            app.window().dispatch_event(WindowEvent::PointerPressed {
                position,
                button: PointerEventButton::Left,
            });
            app.window().dispatch_event(WindowEvent::PointerReleased {
                position,
                button: PointerEventButton::Left,
            });
            assert_eq!(action_rx.try_recv().unwrap(), expected_action);
        }
    }
}

#[test]
fn dashboard_macro_cards_keep_separate_selections_and_use_the_available_height() {
    let window = MinimalSoftwareWindow::new(Default::default());
    slint::platform::set_platform(Box::new(TestDisplay {
        window: window.clone(),
        started: Instant::now(),
        elapsed_offset: Rc::new(Cell::new(Duration::ZERO)),
    }))
    .unwrap();
    let app = App::new().unwrap();
    app.show().unwrap();
    window.set_size(PhysicalSize::new(800, 480));
    let (tx, _rx) = mpsc::unbounded_channel();
    ui_handlers::install(&app, tx);
    let store = Arc::new(Mutex::new(Store::default()));
    dashboard_editor::install(&app, store.clone());
    app.set_connection("Connected".into());

    let names: Vec<_> = (1..=10).map(|index| format!("Macro {index}")).collect();
    {
        let mut store = store.lock().unwrap();
        let manual = names
            .iter()
            .map(|name| (name.clone(), json!({})))
            .collect::<serde_json::Map<_, _>>();
        notifications::apply(
            &app,
            &mut store,
            "notify_macro_update",
            &json!({"macros": manual}),
        );
        let automatic = names
            .iter()
            .map(|name| json!({"name": name, "enabled": true}))
            .collect::<Vec<_>>();
        notifications::apply(
            &app,
            &mut store,
            "notify_auto_macros_update",
            &json!(automatic),
        );
    }
    let (action_tx, action_rx) = std::sync::mpsc::channel();
    let manual = action_tx.clone();
    app.on_trigger_macro(move |name| manual.send(name).unwrap());
    app.on_toggle_auto_macro(move |name, _| action_tx.send(name).unwrap());
    let mut buffer = vec![Rgb8Pixel::default(); 800 * 480];

    for (kind, control_x) in [("macros", 125.), ("auto_macros", 350.)] {
        app.set_dashboard_editing(true);
        app.invoke_dashboard_editor_reset();
        for (slot, card) in [
            ("slot:left-0", kind),
            ("slot:left-1", ""),
            ("slot:right-0", kind),
            ("slot:right-1", "interactions"),
        ] {
            app.invoke_dashboard_open_picker(slot.into());
            app.invoke_dashboard_select_option(card.into());
        }
        assert_eq!(app.get_edit_left_0(), kind);
        assert_eq!(app.get_edit_right_0(), kind);

        for (slot, limit, choices) in [
            ("entries:left-0", 9, &names[..]),
            ("entries:right-0", 4, &names[5..]),
        ] {
            app.invoke_dashboard_open_picker(slot.into());
            assert_eq!(app.get_dashboard_picker_limit(), limit);
            for name in choices {
                app.invoke_dashboard_select_option(name.as_str().into());
            }
            app.invoke_dashboard_apply_picker();
        }
        let selections = app.get_dashboard_macro_selections();
        assert_eq!(selections.row_data(0).unwrap().names.row_count(), 9);
        let right: Vec<_> = selections.row_data(2).unwrap().names.iter().collect();
        assert_eq!(right, ["Macro 6", "Macro 7", "Macro 8", "Macro 9"]);

        app.set_left_slot_0(kind.into());
        app.set_left_slot_1("".into());
        app.set_right_slot_0(kind.into());
        app.set_right_slot_1("interactions".into());
        app.set_dashboard_editing(false);
        slint::platform::update_timers_and_animations();
        window.draw_if_needed(|renderer| {
            renderer.render(&mut buffer, 800);
        });
        let position = LogicalPosition::new(control_x, 384.);
        app.window().dispatch_event(WindowEvent::PointerPressed {
            position,
            button: PointerEventButton::Left,
        });
        app.window().dispatch_event(WindowEvent::PointerReleased {
            position,
            button: PointerEventButton::Left,
        });
        assert_eq!(action_rx.try_recv().unwrap(), "Macro 9");
    }
}

#[test]
fn kiosk_pages_render_and_actions_use_the_displayed_device() {
    let window = MinimalSoftwareWindow::new(Default::default());
    let elapsed_offset = Rc::new(Cell::new(Duration::ZERO));
    slint::platform::set_platform(Box::new(TestDisplay {
        window: window.clone(),
        started: Instant::now(),
        elapsed_offset: elapsed_offset.clone(),
    }))
    .unwrap();
    let app = App::new().unwrap();
    app.show().unwrap();
    window.set_size(PhysicalSize::new(800, 480));
    let (tx, mut rx) = mpsc::unbounded_channel();
    ui_handlers::install(&app, tx);
    app.set_connection("Connected".into());
    let mut store = Store::default();
    for (method, params) in [
        (
            "notify_audio_update",
            json!({"music":{"current_volume":0.5,"pipewire_sink":true,"linked_outputs":["usb"]}}),
        ),
        (
            "notify_audio_outputs_update",
            json!({"outputs":[{"name":"usb","description":"Speakers","volume":0.8}]}),
        ),
        ("notify_macro_update", json!({"macros":{"Start Stream":{}}})),
        (
            "notify_music_update",
            json!({
                "title":"Live Session", "artist":"Streambot", "status":"playing", "shuffle":true
            }),
        ),
        (
            "notify_update_manager",
            json!({"managers":{"backend":{"update_available":true},"system":{"package_count":2}}}),
        ),
        (
            "notify_speedtest_update",
            json!({"stage":"finished","download_mbps":120.0}),
        ),
    ] {
        notifications::apply(&app, &mut store, method, &params);
    }
    assert_eq!(app.get_music_title(), "Live Session");
    assert_eq!(app.get_music_artist(), "Streambot");
    assert!(app.get_music_playing());
    app.set_routing("music".into());
    let music = app.get_audio_interfaces().row_data(0).unwrap();
    assert!(music.links.row_data(0).unwrap().linked);
    app.invoke_change_volume(music, 0.25, false);
    assert_eq!(
        rx.try_recv().unwrap(),
        (
            "set_volume".into(),
            json!({"interface":"music","volume":0.25})
        )
    );
    app.invoke_update_all();
    assert_eq!(
        rx.try_recv().unwrap(),
        ("update".into(), json!({"name":"system"}))
    );
    notifications::apply(
        &app,
        &mut store,
        "notify_update_manager",
        &json!({"managers":{"system":{"package_count":0}}}),
    );
    assert_eq!(
        rx.try_recv().unwrap(),
        ("update".into(), json!({"name":"backend"}))
    );
    assert!(app.invoke_matches("Start Stream".into(), "STREAM".into()));
    notifications::apply(
        &app,
        &mut store,
        "notify_system_info",
        &json!({
            "content": {"components": {"currentLoad": {"currentLoad": 72}, "cpuTemperature": {"main": 48},
            "memory": {"usagePercent": 83}, "swap": {"total": 100, "usage": 14}}}
        }),
    );
    notifications::apply(
        &app,
        &mut store,
        "notify_storage_update",
        &json!({
            "total": 2_000_000_000u64, "used": 1_400_000_000, "free": 600_000_000,
            "folders": {"media": 750_000_000, "webcam": 250_000_000}
        }),
    );
    notifications::apply(
        &app,
        &mut store,
        "notify_update_manager",
        &json!({
            "managers": {"system": {"updating": true, "progress": {"stage": "installing", "percent": 52,
            "package": "test-package", "package_index": 1, "package_total": 2, "package_percent": 30}}}
        }),
    );
    assert_eq!(app.get_system_stats().cpu, 72.);
    assert_eq!(app.get_system_stats().temperature, 48.);
    assert_eq!(app.get_speedtest_download(), "120.0 Mbit/s");
    assert_eq!(app.get_system_stats().ram, 83.);
    assert_eq!(app.get_system_storage().rows.row_count(), 2);
    assert_eq!(
        app.get_updates()
            .iter()
            .find(|r| r.id == "system")
            .unwrap()
            .progress,
        52.
    );
    state::models::dashboard_macros(&app, vec!["Start Stream".into()]);
    app.set_left_slot_0("macros".into());
    dashboard_editor::set_macro_selections(
        &app,
        &[Some(vec!["Start Stream".into()]), None, None, None],
    );
    app.set_dashboard_auto_macros(ModelRc::new(VecModel::from(vec![AutoMacroEntry {
        name: "Studio light".into(),
        enabled: true,
        progress: 0.55,
    }])));
    let mut buffer = vec![Rgb8Pixel::default(); 800 * 480];
    let primary = Rgb8Pixel {
        r: 0xa8,
        g: 0xc7,
        b: 0xfa,
    };
    for page in 0..5 {
        app.set_page(page);
        window.draw_if_needed(|r| {
            r.render(&mut buffer, 800);
        });
        assert!(
            buffer.windows(2).any(|p| p[0] != p[1]),
            "page {page} is blank"
        );
        // Sample both halves of the active pill, clear of its glyph.
        let x = (236 + page * 82 - 15) as usize;
        assert_eq!(buffer[440 * 800 + x], primary, "page {page} nav top");
        assert_eq!(buffer[467 * 800 + x], primary, "page {page} nav bottom");
    }
    let (drawer_tx, drawer_rx) = std::sync::mpsc::channel();
    app.on_drawer_command(move |action, id, password| {
        drawer_tx
            .send((action.to_string(), id.to_string(), password.to_string()))
            .unwrap();
    });
    let url = "http://192.0.2.1:8105/commander";
    let qr = drawer::commander_qr(url).unwrap();
    app.set_commander_url(url.into());
    app.set_commander_qr(slint::Image::from_rgb8(
        slint::SharedPixelBuffer::clone_from_slice(qr.as_raw(), qr.width(), qr.height()),
    ));
    app.set_wifi_available(true);
    app.set_wifi_enabled(true);
    app.set_bluetooth_available(true);
    app.set_bluetooth_powered(true);
    app.set_paired_devices(ModelRc::new(VecModel::from(vec![BluetoothRow {
        id: "paired-0".into(),
        name: "Paired device 0".into(),
        kind: "SPK".into(),
        connected: true,
    }])));
    app.set_saved_wifi(ModelRc::new(VecModel::from(vec![SavedWifiRow {
        id: "profile".into(),
        name: "Saved office".into(),
        ssid: "Office".into(),
        connected: true,
    }])));
    app.set_wifi(ModelRc::new(VecModel::from(vec![
        WifiRow {
            id: "ap1".into(),
            name: "Office".into(),
            device: "wlan0".into(),
            connected: true,
            signal: 90,
            ..Default::default()
        },
        WifiRow {
            id: "ap2".into(),
            name: "Guest".into(),
            signal: 60,
            ..Default::default()
        },
        WifiRow {
            id: "ap3".into(),
            name: "Private".into(),
            secured: true,
            signal: 40,
            ..Default::default()
        },
    ])));
    let press = |x, y| {
        app.window().dispatch_event(WindowEvent::PointerPressed {
            position: LogicalPosition::new(x, y),
            button: PointerEventButton::Left,
        })
    };
    let release = |x, y| {
        app.window().dispatch_event(WindowEvent::PointerReleased {
            position: LogicalPosition::new(x, y),
            button: PointerEventButton::Left,
        })
    };
    let move_pointer = |x, y| {
        app.window().dispatch_event(WindowEvent::PointerMoved {
            position: LogicalPosition::new(x, y),
        })
    };
    assert!(!app.get_dev_page_enabled());
    press(605., 450.);
    release(605., 450.);
    assert_eq!(app.get_page(), 4);

    app.set_connection("Reconnecting".into());
    let settings_dir =
        std::env::temp_dir().join(format!("streambot-dev-test-{}", std::process::id()));
    std::fs::create_dir(&settings_dir).unwrap();
    let settings_path = settings_dir.join("streambot-settings.json");
    std::fs::write(
        &settings_path,
        r#"{"language":"de","touch_wallpaper":"example.jpg"}"#,
    )
    .unwrap();
    assert!(!config::touch_dev_page(&settings_path));
    diagnostics::install(&app, settings_path.clone());
    let backtick = |modifiers, state, repeat| {
        diagnostics::handle_dev_key(
            &app,
            &settings_path,
            PhysicalKey::Code(KeyCode::Backquote),
            modifiers,
            state,
            repeat,
        )
    };
    let plain = ModifiersState::empty();
    assert_eq!(
        backtick(ModifiersState::SHIFT, ElementState::Pressed, false),
        EventResult::Propagate
    );
    assert!(!app.get_dev_page_enabled());
    assert_eq!(
        backtick(plain, ElementState::Pressed, false),
        EventResult::PreventDefault
    );
    assert!(app.get_dev_page_enabled());
    assert!(config::touch_dev_page(&settings_path));
    assert_eq!(app.get_page(), 4, "enabling Dev reveals its tab");
    backtick(plain, ElementState::Pressed, true);
    backtick(plain, ElementState::Released, false);
    assert!(
        app.get_dev_page_enabled(),
        "repeat and release do not toggle Dev"
    );
    assert_eq!(app.get_renderer_info().name, "Slint software");
    assert!(app
        .get_device_diagnostics()
        .iter()
        .any(|row| row.label == "dev_arch" && row.value == std::env::consts::ARCH));
    #[cfg(target_os = "linux")]
    {
        let first = app.invoke_sample_dev_usage(true);
        assert!(first.cpu.is_empty());
        assert!(first.memory.ends_with(" MiB"));
    }
    window.draw_if_needed(|r| {
        r.render(&mut buffer, 800);
    });
    let offline = buffer[..800 * 428].to_vec();
    press(605., 450.);
    release(605., 450.);
    assert_eq!(app.get_page(), 5);
    window.draw_if_needed(|r| {
        r.render(&mut buffer, 800);
    });
    assert_ne!(&buffer[..800 * 428], offline.as_slice());
    assert_eq!(buffer[440 * 800 + 590], primary, "Dev nav pill is active");
    #[cfg(target_os = "linux")]
    {
        let before_sample = buffer[..800 * 428].to_vec();
        elapsed_offset.set(Duration::from_millis(1100));
        slint::platform::update_timers_and_animations();
        window.draw_if_needed(|r| {
            r.render(&mut buffer, 800);
        });
        assert_ne!(
            &buffer[..800 * 428],
            before_sample.as_slice(),
            "Dev updates process usage while open"
        );
    }
    backtick(plain, ElementState::Pressed, false);
    slint::platform::update_timers_and_animations();
    assert!(!app.get_dev_page_enabled());
    assert_eq!(app.get_page(), 0);
    assert!(!config::touch_dev_page(&settings_path));
    assert_eq!(
        serde_json::from_slice::<Value>(&std::fs::read(&settings_path).unwrap()).unwrap(),
        json!({"language": "de", "touch_wallpaper": "example.jpg", "touch_dev_page": false})
    );
    std::fs::write(&settings_path, "{broken").unwrap();
    backtick(plain, ElementState::Pressed, false);
    assert!(!app.get_dev_page_enabled());
    assert_eq!(std::fs::read_to_string(&settings_path).unwrap(), "{broken");
    app.set_feedback("".into());
    std::fs::remove_file(&settings_path).unwrap();
    std::fs::remove_dir(settings_dir).unwrap();
    app.set_page(0);
    for (backend_ready, connection) in [
        (false, "Backend not ready"),
        (true, "Disconnected — retrying"),
    ] {
        app.set_backend_ready(backend_ready);
        app.set_connection(connection.into());
        window.draw_if_needed(|r| {
            r.render(&mut buffer, 800);
        });
        let nav_background = buffer[450 * 800 + 9];
        assert!(
            (434..474).all(|y| buffer[y * 800 + 10..y * 800 + 50]
                .iter()
                .all(|pixel| *pixel == nav_background)),
            "the edit pen is hidden when the connection is {connection}"
        );
        press(30., 471.);
        release(30., 471.);
        assert!(!app.get_dashboard_editing());
    }

    app.set_connection("Connected".into());

    let saved = Rc::new(std::cell::Cell::new(false));
    {
        let saved = saved.clone();
        let weak = app.as_weak();
        app.on_dashboard_save(move |_, _, _, _| {
            saved.set(true);
            weak.unwrap().set_dashboard_editing(false);
        });
    }
    press(30., 471.);
    release(30., 471.);
    assert!(app.get_dashboard_editing());
    press(30., 471.);
    release(30., 471.);
    assert!(saved.get(), "the checkmark saves the dashboard");
    assert!(!app.get_dashboard_editing());
    press(770., 471.);
    release(770., 471.);
    assert!(app.get_power_menu_open());
    app.set_power_menu_open(false);

    app.set_battery_percent(68);
    app.set_battery_charging(true);
    app.set_battery_details(BatteryDetails {
        state: 1,
        minutes: 72,
        watts: 12.5,
        health: 85,
        full_capacity: 48.2,
        design_capacity: 56.7,
        capacity_unit: "Wh".into(),
    });
    let mut history = vec![-1.0; 24];
    history[21..].copy_from_slice(&[52.0, 64.0, 68.0]);
    app.set_battery_history(ModelRc::new(VecModel::from(history)));
    app.set_power_profiles(ModelRc::new(VecModel::from(vec![
        "power-saver".into(),
        "balanced".into(),
    ])));
    app.set_active_power_profile("balanced".into());
    let (profile_tx, profile_rx) = std::sync::mpsc::channel();
    app.on_choose_power_profile(move |profile| profile_tx.send(profile).unwrap());
    press(50., 453.);
    release(50., 453.);
    assert!(
        app.get_power_details_open(),
        "tapping the battery opens its own dialog"
    );
    assert!(!app.get_power_menu_open());
    window.draw_if_needed(|r| {
        r.render(&mut buffer, 800);
    });
    press(200., 359.);
    release(200., 359.);
    assert_eq!(profile_rx.try_recv().unwrap(), "power-saver");
    press(600., 412.);
    release(600., 412.);
    assert!(!app.get_power_details_open());
    app.set_battery_percent(-1);
    press(770., 471.);
    release(770., 471.);
    press(250., 380.);
    release(250., 380.);
    assert!(
        !app.get_power_details_open(),
        "the Power menu has no battery shortcut"
    );
    app.set_power_menu_open(false);
    press(50., 453.);
    release(50., 453.);
    assert!(
        app.get_power_details_open(),
        "power profiles remain accessible without a battery"
    );
    assert!(!app.get_power_menu_open());
    app.set_power_details_open(false);

    app.set_page(1);
    app.set_routing("".into());
    slint::platform::update_timers_and_animations();
    window.draw_if_needed(|r| {
        r.render(&mut buffer, 800);
    });
    press(600., 31.);
    release(600., 31.);
    let slider_rpc = std::iter::from_fn(|| rx.try_recv().ok())
        .find(|(method, _)| method == "set_volume")
        .unwrap();
    assert_eq!(slider_rpc.1["interface"], "music");
    assert!(slider_rpc.1["volume"].as_f64().unwrap() > 0.60);
    press(154., 35.);
    release(154., 35.);
    assert_eq!(app.get_routing(), "music");

    app.set_page(2);
    window.draw_if_needed(|r| {
        r.render(&mut buffer, 800);
    });
    press(144., 65.);
    release(144., 65.);
    slint::platform::update_timers_and_animations();
    assert!(
        app.get_touch_keyboard_open(),
        "focusing macro search must open the keyboard"
    );

    for (language, query) in [("en", "y"), ("de", "yz")] {
        app.set_language(language.into());
        press(440., 305.);
        release(440., 305.);
        slint::platform::update_timers_and_animations();
        assert_eq!(app.get_search(), query);
    }
    app.set_touch_keyboard_symbols(true);
    press(400., 453.);
    release(400., 453.);
    slint::platform::update_timers_and_animations();
    assert_eq!(app.get_search(), "yz ");

    for _ in 0..2 {
        app.window().dispatch_event(WindowEvent::KeyPressed {
            text: Key::LeftArrow.into(),
        });
        app.window().dispatch_event(WindowEvent::KeyReleased {
            text: Key::LeftArrow.into(),
        });
    }
    for (key, query) in [
        ("ä", "yäz "),
        ("x", "yäxz "),
        ("backspace", "yäz "),
        ("`", "yä`z "),
        ("backspace", "yäz "),
    ] {
        app.invoke_keyboard_input(key.into());
        slint::platform::update_timers_and_animations();
        assert_eq!(app.get_search(), query);
    }
    assert!(
        !app.get_dev_page_enabled(),
        "touch keyboard input leaves Dev off"
    );
    app.set_touch_keyboard_symbols(false);
    app.set_language("en".into());

    app.set_page(0);
    slint::platform::update_timers_and_animations();
    assert!(
        !app.get_touch_keyboard_open(),
        "leaving the search page must dismiss the keyboard"
    );
    let (filter_tx, filter_rx) = std::sync::mpsc::channel();
    app.on_dashboard_filter(move |query| filter_tx.send(query).unwrap());
    app.set_dashboard_picker_kind("macros".into());
    app.set_dashboard_picker_open(true);
    window.draw_if_needed(|r| {
        r.render(&mut buffer, 800);
    });
    press(145., 114.);
    release(145., 114.);
    slint::platform::update_timers_and_animations();
    assert!(app.get_touch_keyboard_open());
    app.invoke_keyboard_input("m".into());
    slint::platform::update_timers_and_animations();
    assert_eq!(app.get_dashboard_picker_search(), "m");
    assert_eq!(filter_rx.try_recv().unwrap(), "m");
    app.set_dashboard_picker_open(false);
    slint::platform::update_timers_and_animations();

    window.draw_if_needed(|r| {
        r.render(&mut buffer, 800);
    });
    press(125., 44.);
    release(125., 44.);
    let macro_rpc = std::iter::from_fn(|| rx.try_recv().ok())
        .find(|(method, _)| method == "trigger_macro")
        .unwrap();
    assert_eq!(macro_rpc.1["macro"], "Start Stream");
    assert_eq!(
        app.get_dashboard_macro_list().row_data(0).unwrap().state,
        "loading"
    );

    app.set_page(4);
    app.invoke_speedtest_start();
    app.invoke_speedtest_start();
    assert_eq!(
        std::iter::from_fn(|| rx.try_recv().ok())
            .filter(|(method, params)| method == "speedtest" && params["action"] == "start")
            .count(),
        1
    );

    press(400., 8.);
    move_pointer(400., 200.);
    release(400., 200.);
    assert!(app.get_network_drawer_open());

    // Allow the sheet to settle before testing the controls at their open positions.
    std::thread::sleep(Duration::from_millis(210));
    slint::platform::update_timers_and_animations();
    window.draw_if_needed(|renderer| {
        renderer.render(&mut buffer, 800);
    });
    let qr_pixels = (320..390).flat_map(|y| (550..640).map(move |x| y * 800 + x));
    let white_pixels = qr_pixels
        .filter(|&index| {
            let pixel = buffer[index];
            pixel.r == 255 && pixel.g == 255 && pixel.b == 255
        })
        .count();
    assert!(white_pixels > 100, "the Web Access QR image should render");
    for (y, expected) in [
        (92., ("wifi-disconnect", "wlan0")),
        (143., ("wifi-connect", "ap2")),
    ] {
        press(125., y);
        release(125., y);
        let (action, id, password) = drawer_rx.try_recv().unwrap();
        assert_eq!(
            (action.as_str(), id.as_str(), password.as_str()),
            (expected.0, expected.1, "")
        );
    }
    press(686., 44.);
    release(686., 44.);
    assert_eq!(drawer_rx.try_recv().unwrap().0, "bt-scan");
    press(550., 130.);
    release(550., 130.);
    assert_eq!(
        drawer_rx.try_recv().unwrap(),
        ("bt-disconnect".into(), "paired-0".into(), "".into())
    );
    app.set_bluetooth_scanning(true);
    window.draw_if_needed(|renderer| {
        renderer.render(&mut buffer, 800);
    });
    press(550., 130.);
    release(550., 130.);
    assert_eq!(
        drawer_rx.try_recv().unwrap(),
        ("bt-disconnect".into(), "paired-0".into(), "".into())
    );
    app.set_paired_devices(ModelRc::new(VecModel::from(
        (0..8)
            .map(|index| BluetoothRow {
                id: format!("paired-{index}").into(),
                name: format!("Paired device {index}").into(),
                kind: "SPK".into(),
                connected: index == 0,
            })
            .collect::<Vec<_>>(),
    )));
    window.draw_if_needed(|renderer| {
        renderer.render(&mut buffer, 800);
    });
    press(550., 130.);
    release(550., 130.);
    assert_eq!(
        drawer_rx.try_recv().unwrap(),
        ("bt-disconnect".into(), "paired-0".into(), "".into())
    );
    press(746., 130.);
    release(746., 130.);
    assert_eq!(
        drawer_rx.try_recv().unwrap(),
        ("bt-remove".into(), "paired-0".into(), "".into())
    );
    app.set_bluetooth_scanning(true);
    app.set_discovered_devices(ModelRc::new(VecModel::from(vec![BluetoothRow {
        id: "discovered-1".into(),
        name: "Discovered device".into(),
        kind: "SPK".into(),
        connected: false,
    }])));
    window.draw_if_needed(|renderer| {
        renderer.render(&mut buffer, 800);
    });
    for _ in 0..4 {
        app.window().dispatch_event(WindowEvent::PointerScrolled {
            position: LogicalPosition::new(550., 225.),
            delta_x: 0.,
            delta_y: -120.,
        });
    }
    press(550., 225.);
    release(550., 225.);
    assert_eq!(
        drawer_rx.try_recv().unwrap(),
        ("bt-pair".into(), "discovered-1".into(), "".into())
    );

    press(278., 44.);
    release(278., 44.);
    press(599., 208.);
    release(599., 208.);
    assert!(drawer_rx.try_recv().is_err());
    press(574., 281.);
    release(574., 281.);
    assert_eq!(
        drawer_rx.try_recv().unwrap(),
        ("wifi-forget".into(), "profile".into(), "".into())
    );
    press(607., 301.);
    release(607., 301.);

    press(125., 194.);
    release(125., 194.);
    assert_eq!(app.get_wifi_target(), "ap3");
    assert!(app.get_touch_keyboard_open());
    app.set_wifi_target("".into());
    app.set_touch_keyboard_open(false);

    press(400., 466.);
    move_pointer(400., 300.);
    release(400., 300.);
    assert!(!app.get_network_drawer_open());
    app.hide().unwrap();
}
