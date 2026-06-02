use std::{
    fs::{self, File},
    io::Read,
    os::fd::AsRawFd,
    path::PathBuf,
    process::Command,
    sync::OnceLock,
    thread,
    time::{Duration, Instant},
};

use tauri::{AppHandle, Emitter};

const KEY_POWER: u16 = 116;
const EV_KEY: u16 = 0x01;
const POWER_DEBOUNCE_MS: u64 = 400;

static STARTED: OnceLock<()> = OnceLock::new();

#[repr(C)]
#[derive(Clone, Copy)]
struct InputEvent {
    tv_sec: libc::time_t,
    tv_usec: libc::suseconds_t,
    type_: u16,
    code: u16,
    value: i32,
}

// ioctl number for EVIOCGRAB from linux/input.h
const EVIOCGRAB: libc::c_ulong = 0x40044590;

fn executable_exists(path: &str) -> bool {
    fs::metadata(path).map(|metadata| metadata.is_file()).unwrap_or(false)
}

fn run_first_available(commands: &[(&str, &[&str])]) -> Result<(), String> {
    let mut last_error = None;

    for (program, args) in commands {
        if program.starts_with('/') && !executable_exists(program) {
            continue;
        }

        match Command::new(program).args(*args).status() {
            Ok(status) if status.success() => return Ok(()),
            Ok(status) => last_error = Some(format!("{program} exited with status {status}")),
            Err(error) => last_error = Some(format!("{program}: {error}")),
        }
    }

    Err(last_error.unwrap_or_else(|| "no supported power command found".to_string()))
}

#[tauri::command]
pub fn reboot_system() -> Result<(), String> {
    run_first_available(&[
        ("/usr/bin/systemctl", &["reboot", "-i"]),
        ("/usr/bin/loginctl", &["reboot"]),
        ("/sbin/shutdown", &["-r", "now"]),
        ("/usr/sbin/shutdown", &["-r", "now"]),
        ("/sbin/reboot", &[]),
        ("/bin/busybox", &["reboot"]),
        ("reboot", &[]),
    ])
}

#[tauri::command]
pub fn shutdown_system() -> Result<(), String> {
    run_first_available(&[
        ("/usr/bin/systemctl", &["poweroff", "-i"]),
        ("/usr/bin/loginctl", &["poweroff"]),
        ("/sbin/shutdown", &["-h", "now"]),
        ("/usr/sbin/shutdown", &["-h", "now"]),
        ("/sbin/poweroff", &[]),
        ("/bin/busybox", &["poweroff"]),
        ("poweroff", &[]),
    ])
}


#[tauri::command]
pub fn restart_streambot_service() -> Result<(), String> {
    run_first_available(&[
        ("/usr/bin/systemctl", &["--user", "restart", "stream-overlord.service"]),
        ("/usr/bin/systemctl", &["--user", "restart", "streambot-backend.service"]),
        ("systemctl", &["--user", "restart", "stream-overlord.service"]),
        ("systemctl", &["--user", "restart", "streambot-backend.service"]),
    ])
}

#[cfg(target_os = "linux")]
fn event_devices() -> Vec<PathBuf> {
    fs::read_dir("/dev/input")
        .ok()
        .into_iter()
        .flat_map(|entries| entries.flatten())
        .map(|entry| entry.path())
        .filter(|path| {
            path.file_name()
                .and_then(|name| name.to_str())
                .is_some_and(|name| name.starts_with("event"))
        })
        .collect()
}

#[cfg(target_os = "linux")]
fn supports_key_power(path: &PathBuf) -> bool {
    let Some(event_name) = path.file_name().and_then(|name| name.to_str()) else {
        return false;
    };

    let cap_path = format!("/sys/class/input/{event_name}/device/capabilities/key");
    let Ok(raw) = fs::read_to_string(cap_path) else {
        return false;
    };

    let words: Vec<&str> = raw.split_whitespace().collect();
    let bits_per_word = usize::BITS as usize;

    let word_index = KEY_POWER as usize / bits_per_word;
    let bit_index = KEY_POWER as usize % bits_per_word;

    let Some(word) = words.iter().rev().nth(word_index) else {
        return false;
    };

    let Ok(value) = u128::from_str_radix(word, 16) else {
        return false;
    };

    ((value >> bit_index) & 1) == 1
}

#[cfg(target_os = "linux")]
fn grab(fd: i32, enabled: bool) -> Result<(), String> {
    let value: libc::c_int = if enabled { 1 } else { 0 };
    let result = unsafe { libc::ioctl(fd, EVIOCGRAB, value) };

    if result == 0 {
        Ok(())
    } else {
        Err(std::io::Error::last_os_error().to_string())
    }
}

#[cfg(target_os = "linux")]
fn read_input_event(file: &mut File) -> std::io::Result<InputEvent> {
    let mut event = InputEvent {
        tv_sec: 0,
        tv_usec: 0,
        type_: 0,
        code: 0,
        value: 0,
    };

    let size = std::mem::size_of::<InputEvent>();

    let bytes = unsafe {
        std::slice::from_raw_parts_mut((&mut event as *mut InputEvent) as *mut u8, size)
    };

    file.read_exact(bytes)?;
    Ok(event)
}

#[cfg(target_os = "linux")]
fn listen_device(app: AppHandle, path: PathBuf) {
    thread::spawn(move || {
        let mut file = match File::open(&path) {
            Ok(file) => file,
            Err(error) => {
                eprintln!("[power] failed to open {path:?}: {error}");
                return;
            }
        };

        if let Err(error) = grab(file.as_raw_fd(), true) {
            eprintln!("[power] failed to grab {path:?}: {error}");
            return;
        }

        println!("[power] intercepting KEY_POWER on {path:?}");

        let mut last_press = Instant::now() - Duration::from_secs(10);

        loop {
            let event = match read_input_event(&mut file) {
                Ok(event) => event,
                Err(error) => {
                    eprintln!("[power] read failed on {path:?}: {error}");
                    break;
                }
            };

            if event.type_ != EV_KEY || event.code != KEY_POWER || event.value != 1 {
                continue;
            }

            if last_press.elapsed() < Duration::from_millis(POWER_DEBOUNCE_MS) {
                continue;
            }

            last_press = Instant::now();
            let _ = app.emit("notify_power_button", ());
        }

        let _ = grab(file.as_raw_fd(), false);
    });
}

pub fn start_power_button_intercept(app: AppHandle) {
    if STARTED.set(()).is_err() {
        return;
    }

    #[cfg(not(target_os = "linux"))]
    {
        let _ = app;
        eprintln!("[power] power button interception is only supported on Linux");
    }

    #[cfg(target_os = "linux")]
    {
        let devices: Vec<PathBuf> = event_devices()
            .into_iter()
            .filter(supports_key_power)
            .collect();

        if devices.is_empty() {
            eprintln!("[power] no KEY_POWER input devices found");
            return;
        }

        for device in devices {
            listen_device(app.clone(), device);
        }
    }
}
