#!/bin/bash
set -e

green=$(echo -en "\e[92m")
yellow=$(echo -en "\e[93m")
red=$(echo -en "\e[91m")
default=$(echo -en "\e[39m")

RULE_FILE="/etc/polkit-1/rules.d/50-networkmanager.rules"

status_msg(){ echo; echo -e "${yellow}###### $1${default}"; }
ok_msg(){ echo -e "${green}>>>>>> $1${default}"; }
warn_msg(){ echo -e "${red} $1${default}"; }

if [[ ${UID} == '0' ]]; then
  warn_msg "You can't run this script as root!"
  exit 1
fi

get_target_user() {
  if command -v logname >/dev/null 2>&1 && logname >/dev/null 2>&1; then
    logname
  else
    echo "$USER"
  fi
}

install_networkmanager_polkit_rule() {
  local target_user
  target_user="$(get_target_user)"

  if [[ -z "$target_user" ]]; then
    warn_msg "Could not detect target user."
    exit 1
  fi

  status_msg "Installing NetworkManager polkit rule for user: $target_user"

  sudo mkdir -p /etc/polkit-1/rules.d

  sudo tee "$RULE_FILE" > /dev/null <<EOF_RULE
polkit.addRule(function(action, subject) {
    if (
        subject.user == "$target_user" &&
        action.id.indexOf("org.freedesktop.NetworkManager.") == 0
    ) {
        return polkit.Result.YES;
    }
});
EOF_RULE

  sudo chmod 644 "$RULE_FILE"

  status_msg "Reloading polkit"
  sudo systemctl restart polkit.service 2>/dev/null || sudo systemctl restart polkit 2>/dev/null || true

  ok_msg "Installed: $RULE_FILE"
}

install_networkmanager_polkit_rule
