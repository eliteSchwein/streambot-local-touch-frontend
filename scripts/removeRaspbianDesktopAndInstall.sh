#!/bin/bash
set -e

green=$(echo -en "\e[92m")
yellow=$(echo -en "\e[93m")
red=$(echo -en "\e[91m")
default=$(echo -en "\e[39m")

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

status_msg(){ echo; echo -e "${yellow}###### $1${default}"; }
ok_msg(){ echo -e "${green}>>>>>> $1${default}"; }
warn_msg(){ echo -e "${red} $1${default}"; }

if [[ ${UID} == '0' ]]; then
  warn_msg "You can't run this script as root!"
  exit 1
fi

if [[ ! -x "$SCRIPTPATH/install.sh" ]]; then
  warn_msg "install.sh not found or not executable in: $SCRIPTPATH"
  warn_msg "Run: chmod +x install.sh"
  exit 1
fi

confirm_remove_desktop() {
  echo
  warn_msg "This will remove the Raspberry Pi desktop environment from this system."
  warn_msg "It keeps the base OS, SSH, networking, users, and systemd."
  read -r -p "Continue? [y/N]: " answer

  case "$answer" in
    y|Y|yes|YES)
      ;;
    *)
      warn_msg "Aborted."
      exit 1
      ;;
  esac
}

stop_desktop_services() {
  status_msg "Stopping desktop/display services if present"

  sudo systemctl disable --now lightdm.service 2>/dev/null || true
  sudo systemctl disable --now gdm.service 2>/dev/null || true
  sudo systemctl disable --now sddm.service 2>/dev/null || true
  sudo systemctl set-default multi-user.target
}

remove_raspbian_desktop() {
  status_msg "Removing Raspberry Pi desktop packages"

  sudo apt update

  sudo apt-get -y purge \
    raspberrypi-ui-mods \
    task-desktop \
    task-lxde-desktop \
    lxde \
    lxde-core \
    lxpanel \
    lxsession \
    pcmanfm \
    openbox \
    lightdm \
    xserver-xorg \
    xinit \
    x11-common \
    realvnc-vnc-server \
    wolfram-engine \
    libreoffice* \
    scratch* \
    sonic-pi \
    geany \
    claws-mail \
    chromium-browser \
    rpi-chromium-mods rpi-firefox-mods \
    firefox \
    chromium \
    mate-desktop-common \
    rpi-imager \
    2>/dev/null || true

  status_msg "Cleaning unused packages"
  sudo apt-get -y autoremove --purge
  sudo apt-get -y autoclean
}

run_streambot_installer() {
  status_msg "Running Streambot Touch installer"
  "$SCRIPTPATH/install.sh" "$@"
}

confirm_remove_desktop
stop_desktop_services
remove_raspbian_desktop
run_streambot_installer "$@"

ok_msg "Desktop removed and Streambot Touch installer finished. Reboot is recommended."
