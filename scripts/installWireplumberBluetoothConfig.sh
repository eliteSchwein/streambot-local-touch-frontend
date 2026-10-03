#!/bin/bash
set -euo pipefail

CONFIG_DIR="$HOME/.config/wireplumber/wireplumber.conf.d"
CONFIG_FILE="$CONFIG_DIR/80-streambot-bluetooth.conf"

echo
echo "###### Configure WirePlumber Bluetooth for kiosk/headless session"

mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_FILE" <<'EOF'
wireplumber.profiles = {
  main = {
    monitor.bluez.seat-monitoring = disabled
  }
}
EOF

echo ">>>>>> Wrote $CONFIG_FILE"

# Reload the user's audio session so the BlueZ monitor is re-created with
# seat monitoring disabled. This is needed for the Streambot Touch kiosk,
# whose logind sessions intentionally have no seat assigned.
systemctl --user daemon-reload || true
systemctl --user restart wireplumber.service || true

echo ">>>>>> WirePlumber Bluetooth kiosk configuration applied"
