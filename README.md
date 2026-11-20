# Streambot Touch

Streambot Touch is a native Rust and Slint touchscreen kiosk for the Streambot backend. It opens fullscreen on Wayland or X11 and renders its controls and keyboard in-process. The kiosk installer uses labwc on Debian Trixie.

## Build and run

With a current stable Rust toolchain, run the following from the repository root.

```sh
cargo run --locked --release
```

The default connection is localhost, with REST on port 8105 and WebSocket on port 8100. Supply an existing configuration file with `--app-config` or `STREAMBOT_TOUCH_CONFIG`.

```sh
cargo run --locked --release -- --app-config /path/to/streambot-touch.cfg
```

The default configuration directory is `~/.config/streambot` or `$XDG_CONFIG_HOME/streambot`. The kiosk reads `streambot-touch.cfg` and shares dashboard, wallpaper and language settings in `streambot-settings.json`. Wallpaper paths are relative to the `assets` directory.

Slint tries Vulkan first, then OpenGL, and falls back to software rendering when accelerated rendering is unavailable. To force the software renderer, set `SLINT_BACKEND=winit-software` when launching the app.

Press the physical backtick key (usually above Tab) to toggle Dev mode. This saves the new `touch_dev_page` value in `streambot-settings.json` so it takes effect at the next startup too. The Dev tab displays the active renderer, available graphics adapter and driver details, and the desktop environment and Wayland compositor when identified. On Linux it samples the Touch process's CPU and resident RAM once a second while the tab is open. The page works while the Streambot backend is offline.

## Kiosk controls

Use the bottom navigation to switch between the dashboard, audio, macros, system and speedtest pages. The dashboard editor saves card placement and selected macros. The audio page controls virtual and physical outputs, mute, routing and per-output volume. The system page shows resource usage, folder storage and updates. Update all runs the backend update last.

Tap or pull down the top grip to manage Ethernet, Wi-Fi and Bluetooth or scan the Commander QR code. The power menu is accessible from the bottom bar and from the kiosk's hardware power key. Physical audio controls use `pactl`. The connection drawer talks directly to NetworkManager and BlueZ over system D-Bus; it does not invoke `nmcli` or `bluetoothctl`. Those daemons must be running, and the kiosk user must have system-bus access under the host's D-Bus policy. Bluetooth pairing registers a temporary `NoInputNoOutput` agent for the device selected in the drawer.

Tap the battery indicator at the left of the bottom bar to open **Battery and power**. The dialog shows the current charge, estimated time remaining or time until full, battery power, and charge history for the last 24 hours where data is available. It uses saved UPower history for a single system battery and supplements it with readings collected while Touch is running. On devices without a battery, **Power profile** appears at the same spot when profiles are available.

The dialog lists the profiles provided by `power-profiles-daemon` and highlights the active profile. Switching requires the daemon and Polkit permission. The kiosk installer grants profile switching to the configured kiosk user.

## Debian package

Build on the Debian release and architecture that will run the kiosk. Install the native build dependencies and build the package.

```sh
sudo apt-get install build-essential dpkg-dev pkg-config python3 libfontconfig1-dev libwayland-dev libxkbcommon-dev
./packaging/build-deb.sh
```

The script writes the architecture-specific package to `dist-artifacts/`. To install on an existing desktop, use `sudo apt install ./dist-artifacts/*.deb` with the matching package. To provision a dedicated Trixie kiosk, pass its absolute path to the installer.

```sh
STREAMBOT_TOUCH_DEB=/absolute/path/to/streambot-touch_VERSION.trixie_arm64.deb ./scripts/install.sh
```

The kiosk installer configures labwc autostart, systemd, audio, network permissions and power-key handling. Release workflows build amd64 and arm64 packages for Bookworm and Trixie.

## Verification

`cargo test --locked` includes an 800×480 software-rendering test for all five pages. On Linux with Xvfb and Python aiohttp available, the following test starts the release executable on a virtual display and exercises readiness, WebSocket registration, reconnect, CAVA and the power-menu signal using a local test backend.

```sh
cargo build --release --locked
python3 packaging/smoke-test.py target/release/streambot-touch
```
