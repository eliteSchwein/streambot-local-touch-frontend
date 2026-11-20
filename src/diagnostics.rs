use crate::{config, App, DiagnosticRow, RendererInfo};
use slint::wgpu_30::wgpu::Backend;
use slint::winit_030::{
    winit::{
        event::{ElementState, WindowEvent},
        keyboard::{KeyCode, ModifiersState, PhysicalKey},
    },
    EventResult, WinitWindowAccessor,
};
use slint::{
    ComponentHandle, GraphicsAPI, Model, ModelRc, RenderingState, SetRenderingNotifierError,
    VecModel,
};
use std::{
    env,
    ffi::{c_char, c_void, CStr},
    fs,
    path::{Path, PathBuf},
    thread,
};

mod process;

pub(crate) fn set_enabled(app: &App, enabled: bool) {
    if enabled && app.get_device_diagnostics().row_count() == 0 {
        app.set_device_diagnostics(device_info());
    }
    app.set_dev_page_enabled(enabled);
}

pub(crate) fn install(app: &App, settings_path: PathBuf) {
    install_shortcut(app, settings_path);
    let mut sampler = process::Sampler::default();
    app.on_sample_dev_usage(move |reset| sampler.sample(reset));
    // Record the renderer during setup so diagnostics are ready if Dev is enabled later.
    // Skia's software surface accepts the notifier and has no graphics API to report.
    app.set_renderer_info(renderer("Skia (software)"));

    let weak = app.as_weak();
    let mut read_opengl = false;
    let result = app
        .window()
        .set_rendering_notifier(move |state, api| match (state, api) {
            (RenderingState::RenderingSetup, GraphicsAPI::WGPU30 { device, .. }) => {
                if let Some(app) = weak.upgrade() {
                    let adapter = device.adapter_info();
                    app.set_renderer_info(RendererInfo {
                        name: format!("Skia · {:?} (wgpu)", adapter.backend).into(),
                        adapter: adapter.name.into(),
                        driver: [adapter.driver, adapter.driver_info]
                            .into_iter()
                            .filter(|part| !part.is_empty())
                            .collect::<Vec<_>>()
                            .join(" · ")
                            .into(),
                    });
                    if adapter.backend == Backend::Vulkan {
                        app.invoke_enable_gpu_effects();
                    }
                }
            }
            (RenderingState::RenderingSetup, GraphicsAPI::NativeOpenGL { .. }) => {
                read_opengl = true;
            }
            (RenderingState::AfterRendering, GraphicsAPI::NativeOpenGL { get_proc_address })
                if read_opengl =>
            {
                // At this point the renderer has made its OpenGL context current.
                read_opengl = false;
                if let Some(app) = weak.upgrade() {
                    app.set_renderer_info(opengl_info(get_proc_address));
                }
            }
            _ => {}
        });
    match result {
        // With this build's renderer features the Slint software renderer is the
        // renderer that rejects a notifier. Skia accepts it for all surfaces.
        Err(SetRenderingNotifierError::Unsupported) => {
            app.set_renderer_info(renderer("Slint software"));
        }
        Ok(()) => {}
        Err(error) => {
            app.set_renderer_info(RendererInfo::default());
            eprintln!("Rendering notifier unavailable, animations disabled: {error}");
        }
    }
}

fn install_shortcut(app: &App, settings_path: PathBuf) {
    let weak = app.as_weak();
    let mut modifiers = ModifiersState::empty();
    // The touch keyboard dispatches Slint events directly, so it bypasses this filter.
    app.window().on_winit_window_event(move |_, event| {
        match event {
            WindowEvent::ModifiersChanged(next) => modifiers = next.state(),
            WindowEvent::Focused(false) => modifiers = ModifiersState::empty(),
            WindowEvent::KeyboardInput {
                event,
                is_synthetic: false,
                ..
            } => {
                if let Some(app) = weak.upgrade() {
                    return handle_dev_key(
                        &app,
                        &settings_path,
                        event.physical_key,
                        modifiers,
                        event.state,
                        event.repeat,
                    );
                }
            }
            _ => {}
        }
        EventResult::Propagate
    });
}

pub(super) fn handle_dev_key(
    app: &App,
    settings_path: &Path,
    key: PhysicalKey,
    modifiers: ModifiersState,
    state: ElementState,
    repeat: bool,
) -> EventResult {
    if key != PhysicalKey::Code(KeyCode::Backquote) || !modifiers.is_empty() {
        return EventResult::Propagate;
    }
    if state.is_pressed() && !repeat {
        let enabled = !app.get_dev_page_enabled();
        match config::save_touch_dev_page(settings_path, enabled) {
            Ok(()) => set_enabled(app, enabled),
            Err(error) => {
                let message = format!("Could not save Dev mode: {error}");
                eprintln!("{message}");
                app.set_feedback(message.into());
            }
        }
    }
    EventResult::PreventDefault
}

fn renderer(name: &str) -> RendererInfo {
    RendererInfo {
        name: name.into(),
        ..Default::default()
    }
}

fn opengl_info(get_proc_address: &dyn Fn(&CStr) -> *const c_void) -> RendererInfo {
    let mut info = renderer("Skia · OpenGL");
    let address = get_proc_address(c"glGetString");
    if !address.is_null() {
        // Slint's notifier supplies the OpenGL loader with its context current.
        // glGetString uses the platform GL calling convention and returns a
        // NUL-terminated driver-owned string valid while the context is alive.
        let get_string: unsafe extern "system" fn(u32) -> *const c_char =
            unsafe { std::mem::transmute(address) };
        let read = |field| {
            let ptr = unsafe { get_string(field) };
            if ptr.is_null() {
                String::new()
            } else {
                unsafe { CStr::from_ptr(ptr) }
                    .to_string_lossy()
                    .into_owned()
            }
        };
        info.adapter = read(0x1F01).into(); // GL_RENDERER
        info.driver = read(0x1F02).into(); // GL_VERSION includes driver version when reported.
    }
    info
}

fn device_info() -> ModelRc<DiagnosticRow> {
    let os_release = fs::read_to_string("/etc/os-release")
        .or_else(|_| fs::read_to_string("/usr/lib/os-release"))
        .unwrap_or_default();
    let os = field(&os_release, '=', "PRETTY_NAME")
        .map(|name| name.trim_matches(['"', '\'']))
        .unwrap_or(env::consts::OS);
    let cpu_info = fs::read_to_string("/proc/cpuinfo").unwrap_or_default();
    let cpu = field(&cpu_info, ':', "model name")
        .or_else(|| field(&cpu_info, ':', "Hardware"))
        .unwrap_or_default();
    let cpus = thread::available_parallelism()
        .map(|count| count.to_string())
        .unwrap_or_default();
    let mem_info = fs::read_to_string("/proc/meminfo").unwrap_or_default();
    let memory = field(&mem_info, ':', "MemTotal")
        .and_then(|value| value.split_whitespace().next())
        .and_then(|kib| kib.parse::<u64>().ok())
        .map(|kib| format!("{:.1} GiB", kib as f64 / (1024.0 * 1024.0)))
        .unwrap_or_default();
    let board = fs::read_to_string("/proc/device-tree/model")
        .or_else(|_| fs::read_to_string("/sys/class/dmi/id/product_name"))
        .unwrap_or_default();
    let kernel = fs::read_to_string("/proc/sys/kernel/osrelease").unwrap_or_default();
    let session = env::var("XDG_SESSION_TYPE").unwrap_or_default();
    let desktop = [
        "XDG_CURRENT_DESKTOP",
        "XDG_SESSION_DESKTOP",
        "DESKTOP_SESSION",
    ]
    .into_iter()
    .find_map(|key| env::var(key).ok().filter(|value| !value.trim().is_empty()))
    .unwrap_or_default()
    .replace(':', " / ");
    #[cfg(target_os = "linux")]
    let compositor = wayland_compositor(&session).unwrap_or_default();
    #[cfg(not(target_os = "linux"))]
    let compositor = String::new();
    let backend_override = env::var("SLINT_BACKEND").unwrap_or_default();

    ModelRc::new(VecModel::from(
        [
            ("dev_device", board.trim_end_matches('\0').trim()),
            ("dev_cpu", cpu),
            ("dev_arch", env::consts::ARCH),
            ("dev_cpu_count", &cpus),
            ("dev_memory", &memory),
            ("dev_os", os),
            ("dev_kernel", kernel.trim()),
            ("dev_desktop", &desktop),
            ("dev_compositor", &compositor),
            ("dev_session", &session),
            ("dev_app_version", env!("CARGO_PKG_VERSION")),
            ("dev_ui_stack", "Slint / Winit"),
            ("dev_backend_override", &backend_override),
        ]
        .into_iter()
        .map(|(label, value)| DiagnosticRow {
            label: label.into(),
            value: value.into(),
        })
        .collect::<Vec<_>>(),
    ))
}

#[cfg(target_os = "linux")]
fn wayland_compositor(session_type: &str) -> Option<String> {
    let display = env::var_os("WAYLAND_DISPLAY")
        .filter(|name| !name.is_empty())
        .or_else(|| (session_type == "wayland").then(|| "wayland-0".into()))?;
    let mut path = PathBuf::from(display);
    if !path.is_absolute() {
        path = PathBuf::from(env::var_os("XDG_RUNTIME_DIR")?).join(path);
    }
    wayland_socket_owner(&path)
}

#[cfg(target_os = "linux")]
fn wayland_socket_owner(path: &Path) -> Option<String> {
    use rustix::net::{
        connect, socket_with, sockopt, AddressFamily, SocketAddrUnix, SocketFlags, SocketType,
    };

    let socket = socket_with(
        AddressFamily::UNIX,
        SocketType::STREAM,
        SocketFlags::CLOEXEC | SocketFlags::NONBLOCK,
        None,
    )
    .ok()?;
    connect(&socket, &SocketAddrUnix::new(path).ok()?).ok()?;
    let pid = sockopt::socket_peercred(&socket).ok()?.pid.as_raw_pid();
    let name = fs::read_link(format!("/proc/{pid}/exe"))
        .ok()
        .and_then(|path| {
            path.file_name()
                .map(|name| name.to_string_lossy().into_owned())
        })
        .or_else(|| fs::read_to_string(format!("/proc/{pid}/comm")).ok())?;
    let name = name.trim();
    // A socket managed by systemd can report systemd as the peer.
    (!name.is_empty() && name != "systemd").then(|| name.to_owned())
}

#[cfg(all(test, target_os = "linux"))]
mod tests {
    use super::*;
    use std::os::unix::net::UnixListener;

    #[test]
    #[ignore = "requires permission to bind a Unix socket and read peer credentials"]
    fn identifies_wayland_socket_owner() {
        let path = env::temp_dir().join(format!("streambot-wayland-test-{}", std::process::id()));
        let listener = UnixListener::bind(&path).unwrap();
        let result = wayland_socket_owner(&path);
        drop(listener);
        fs::remove_file(&path).unwrap();

        let executable = env::current_exe().unwrap();
        assert_eq!(result.as_deref(), executable.file_name().unwrap().to_str());
    }
}

fn field<'a>(contents: &'a str, separator: char, key: &str) -> Option<&'a str> {
    contents.lines().find_map(|line| {
        let (name, value) = line.split_once(separator)?;
        let value = value.trim();
        (name.trim() == key && !value.is_empty()).then_some(value)
    })
}
