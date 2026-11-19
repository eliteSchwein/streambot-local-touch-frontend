use super::*;
use serde_json::json;
use slint::platform::{software_renderer::MinimalSoftwareWindow, Platform, WindowAdapter};
use slint::platform::{Key, PointerEventButton, WindowEvent};
use slint::{LogicalPosition, Model, ModelRc, PhysicalSize, PlatformError, Rgb8Pixel, VecModel};
use std::rc::Rc;

struct TestDisplay(Rc<MinimalSoftwareWindow>);

impl Platform for TestDisplay {
    fn create_window_adapter(&self) -> Result<Rc<dyn WindowAdapter>, PlatformError> {
        Ok(self.0.clone())
    }
}

#[test]
fn kiosk_pages_render_and_actions_use_the_displayed_device() {
    let window = MinimalSoftwareWindow::new(Default::default());
    slint::platform::set_platform(Box::new(TestDisplay(window.clone()))).unwrap();
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
    app.set_page(0);
    press(30., 471.);
    release(30., 471.);
    assert!(app.get_dashboard_editing());
    press(30., 471.);
    release(30., 471.);
    assert!(!app.get_dashboard_editing());
    press(770., 471.);
    release(770., 471.);
    assert!(app.get_power_menu_open());
    app.set_power_menu_open(false);

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
    for (key, query) in [("ä", "yäz "), ("x", "yäxz "), ("backspace", "yäz ")] {
        app.invoke_keyboard_input(key.into());
        slint::platform::update_timers_and_animations();
        assert_eq!(app.get_search(), query);
    }
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
