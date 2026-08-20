#!/bin/bash
set -euo pipefail

green=$(echo -en "\e[92m")
yellow=$(echo -en "\e[93m")
red=$(echo -en "\e[91m")
default=$(echo -en "\e[39m")

status_msg(){ echo; echo -e "${yellow}###### $1${default}"; }
ok_msg(){ echo -e "${green}>>>>>> $1${default}"; }
warn_msg(){ echo -e "${red} $1${default}"; }

if [[ ${UID} == 0 ]]; then
    warn_msg "Run this script as the Streambot Touch user, not as root."
    exit 1
fi

TARGET_USER="${SUDO_USER:-$USER}"

if ! id "$TARGET_USER" >/dev/null 2>&1; then
    warn_msg "User does not exist: $TARGET_USER"
    exit 1
fi

RULE_FILE="/etc/polkit-1/rules.d/49-streambot-touch-networkmanager.rules"

status_msg "Installing Streambot Touch NetworkManager Polkit rule for $TARGET_USER"

sudo install -d -m 0755 /etc/polkit-1/rules.d

sudo tee "$RULE_FILE" >/dev/null <<EOF
// Streambot Touch kiosk NetworkManager permissions.
//
// Deliberately limited to the NetworkManager actions used by the touch UI.
// This does NOT grant unrestricted NetworkManager or general root access.

polkit.addRule(function(action, subject) {
    if (subject.user !== "${TARGET_USER}") {
        return polkit.Result.NOT_HANDLED;
    }

    var allowedActions = [
        // Toggle the NetworkManager Wi-Fi radio.
        "org.freedesktop.NetworkManager.enable-disable-wifi",

        // Connect/disconnect wired and wireless connections.
        "org.freedesktop.NetworkManager.network-control",

        // Connect to / update system-wide saved NetworkManager profiles.
        "org.freedesktop.NetworkManager.settings.modify.system",

        // Connect to / update profiles owned by this user.
        "org.freedesktop.NetworkManager.settings.modify.own",

        // Allow active Wi-Fi scans.
        "org.freedesktop.NetworkManager.wifi.scan"
    ];

    if (allowedActions.indexOf(action.id) !== -1) {
        return polkit.Result.YES;
    }

    return polkit.Result.NOT_HANDLED;
});
EOF

sudo chmod 0644 "$RULE_FILE"

status_msg "Reloading Polkit rules"

# polkit watches rules.d automatically. A restart makes the new rule effective
# immediately on systems where the daemon has not noticed the change yet.
if systemctl list-unit-files polkit.service >/dev/null 2>&1; then
    sudo systemctl try-restart polkit.service || true
fi

status_msg "Current NetworkManager permissions"

nmcli general permissions 2>/dev/null | grep -E \
    'enable-disable-wifi|network-control|settings.modify.(system|own)|wifi.scan' \
    || true

ok_msg "NetworkManager Polkit permissions installed"
