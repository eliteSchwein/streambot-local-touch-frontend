# Streambot Touch

Touchscreen frontend for Streambot, built with [Quickshell](https://quickshell.org/) and QML.

Streambot Touch is intended to run as a lightweight Wayland kiosk interface, primarily on Raspberry Pi hardware. It uses Labwc as the Wayland compositor and communicates with the Streambot backend over WebSocket.

The application is packaged as a Debian package and is installed as `/usr/bin/streambot-touch`.

## Requirements

The installer currently targets:

- Debian 13 (Trixie)
- Wayland
- Labwc
- Quickshell
- NetworkManager
- a non-root user with `sudo` access

Quickshell is installed from Debian Trixie Backports.

## Installation

### Recommended: install directly from GitHub

The repository does **not** need to be cloned.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/eliteSchwein/streambot-local-touch-frontend/main/scripts/install-remote.sh)
```

The bootstrap script downloads the installer files into a temporary directory, starts the normal installer, and removes the temporary files afterwards.

The installer:

- verifies that the system is Debian 13 (Trixie)
- enables Debian Trixie Backports
- enables `apt.tludwig.dev`
- installs Quickshell and kiosk dependencies
- installs the `streambot-touch` Debian package
- configures user permissions
- installs NetworkManager and power polkit rules
- installs the Labwc kiosk configuration
- creates the Streambot Touch systemd user service

A reboot is recommended after installation.

### Install from a cloned repository

```bash
git clone https://github.com/eliteSchwein/streambot-local-touch-frontend.git
cd streambot-local-touch-frontend
./scripts/install.sh
```

Do **not** run the installer as root. It uses `sudo` when elevated permissions are required.

## Configuration

The default configuration file is:

```text
~/.config/streambot/streambot-touch.cfg
```

The installer asks for the configuration path during setup.

A different configuration can also be supplied to the installer:

```bash
./scripts/install.sh --app_config=/path/to/streambot-touch.cfg
```

The installed launcher accepts:

```bash
streambot-touch --app-config /path/to/streambot-touch.cfg
```

`--config_path` is also accepted for compatibility.

The selected path is exposed to the Quickshell application through:

```text
STREAMBOT_TOUCH_CONFIG
```

## Running Streambot Touch

The Debian package installs the launcher at:

```text
/usr/bin/streambot-touch
```

The launcher starts Quickshell with the packaged QML application:

```text
/usr/share/streambot-touch
```

Internally this is equivalent to:

```bash
qs --path /usr/share/streambot-touch
```

The normal kiosk installation starts Streambot Touch through its generated systemd user service rather than manually.

## Project structure

```text
.
├── .github/workflows/   GitHub Actions
├── helper/              Runtime helper programs
├── packaging/           Debian packaging and launcher
├── scripts/             Installation and kiosk setup scripts
├── src/                 Quickshell/QML application
├── package.json         Package version
└── README.md
```

## Debian package

The application is shipped as the `streambot-touch` Debian package.

Build it with:

```bash
./packaging/build-deb.sh
```

The package contains:

```text
/usr/bin/streambot-touch
/usr/lib/streambot-touch/
/usr/share/streambot-touch/
```

The QML application from `src/` is copied directly into `/usr/share/streambot-touch/`.

By default the resulting package is written to:

```text
dist-artifacts/
```

with a filename similar to:

```text
streambot-touch_<version>.trixie_all.deb
```

The package version is read from `package.json`.

## Development

For local development, install Quickshell and the required Qt/QML modules, then run the source tree directly:

```bash
qs --path ./src
```

If a specific Streambot Touch config should be used:

```bash
STREAMBOT_TOUCH_CONFIG="$HOME/.config/streambot/streambot-touch.cfg" qs --path ./src
```

## Updating

Installed releases are distributed through:

```text
https://apt.tludwig.dev
```

After the repository has been configured by the installer, normal package updates can be installed through APT:

```bash
sudo apt update
sudo apt upgrade
```

## License

GPL-3.0
