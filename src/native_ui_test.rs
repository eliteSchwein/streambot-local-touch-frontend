use super::*;
use serde_json::json;
use slint::platform::{software_renderer::MinimalSoftwareWindow, Platform, WindowAdapter};
use slint::{Model, PhysicalSize, PlatformError, Rgb8Pixel};
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
    let mut buffer = vec![Rgb8Pixel::default(); 800 * 480];
    for page in 0..5 {
        app.set_page(page);
        window.draw_if_needed(|r| {
            r.render(&mut buffer, 800);
        });
        assert!(
            buffer.windows(2).any(|p| p[0] != p[1]),
            "page {page} is blank"
        );
    }
    app.hide().unwrap();
}
