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

RULE_FILE="/etc/polkit-1/rules.d/49-streambot-touch-power.rules"

status_msg "Installing Streambot Touch power Polkit rule for $TARGET_USER"

sudo install -d -m 0755 /etc/polkit-1/rules.d

sudo tee "$RULE_FILE" >/dev/null <<EOF
// Streambot Touch kiosk power permissions.
//
// Limited to power-off and reboot via systemd-logind.

polkit.addRule(function(action, subject) {
    if (subject.user !== "${TARGET_USER}") {
        return polkit.Result.NOT_HANDLED;
    }

    var allowedActions = [
        "org.freedesktop.login1.power-off",
        "org.freedesktop.login1.power-off-multiple-sessions",
        "org.freedesktop.login1.reboot",
        "org.freedesktop.login1.reboot-multiple-sessions"
    ];

    if (allowedActions.indexOf(action.id) !== -1) {
        return polkit.Result.YES;
    }

    return polkit.Result.NOT_HANDLED;
});
EOF

sudo chmod 0644 "$RULE_FILE"

if systemctl list-unit-files polkit.service >/dev/null 2>&1; then
    sudo systemctl try-restart polkit.service || true
fi

ok_msg "Power Polkit permissions installed"
