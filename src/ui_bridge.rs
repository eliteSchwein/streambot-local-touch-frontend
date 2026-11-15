use crate::App;

pub(crate) fn ui_event(ui: &slint::Weak<App>, f: impl FnOnce(App) + Send + 'static) {
    let weak = ui.clone();
    let _ = slint::invoke_from_event_loop(move || {
        if let Some(app) = weak.upgrade() {
            f(app);
        }
    });
}
