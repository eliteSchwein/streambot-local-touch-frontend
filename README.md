# Streambot Touch Native (Rust + Slint)

A native Rust/Slint migration of the original Quickshell Streambot Touch kiosk.

**UI parity is in progress.** This revision restores the original page
layout, 52 px bottom navigation, default two-column dashboard, and Material 3
fallback colors. See [UI_PORT_STATUS.md](UI_PORT_STATUS.md) for a precise
feature-by-feature list of incomplete elements.

Build:

```sh
cargo build
cargo run
```

Settings are read from `~/.config/streambot/streambot-touch.cfg`, or a file
supplied using `--app-config /path/to/file` or `STREAMBOT_TOUCH_CONFIG`.
The existing backend must be available on the configured REST and WebSocket
ports (defaults: 8105 and 8100).

The Rust entrypoint is `src/main.rs`; the native UI is `ui/app.slint`.

## Source organization

See [ARCHITECTURE.md](ARCHITECTURE.md) for a map of the Rust modules after the application was refactored out of `main.rs`.
