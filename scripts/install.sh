#!/bin/bash
set -e

green=$(echo -en "\e[92m")
yellow=$(echo -en "\e[93m")
red=$(echo -en "\e[91m")
cyan=$(echo -en "\e[96m")
default=$(echo -en "\e[39m")

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

MCSERVICENAME="streambottouch"
MCCONFIGFILE="/home/$(whoami)/streambot-touch.cfg"

status_msg(){ echo; echo -e "${yellow}###### $1${default}"; }
ok_msg(){ echo -e "${green}>>>>>> $1${default}"; }
warn_msg(){ echo -e "${red} $1${default}"; }
title_msg(){ echo -e "${cyan}$1${default}"; }

for ARGUMENT in "$@"; do
  KEY=$(echo "$ARGUMENT" | cut -f1 -d=)
  VALUE=$(echo "$ARGUMENT" | cut -f2- -d=)

  case "$KEY" in
    --config_path|--app_config)
      MCCONFIGFILE="${VALUE}"
      ;;
    --service_suffix)
      MCSERVICENAME="${MCSERVICENAME}_${VALUE}"
      ;;
  esac
done

if [[ ${UID} == '0' ]]; then
  warn_msg "You can't run this script as root!"
  exit 1
fi


check_distribution() {
  status_msg "Check Debian version"

  if [[ ! -r /etc/os-release ]]; then
    warn_msg "Unable to detect the operating system."
    exit 1
  fi

  . /etc/os-release

  if [[ "${ID:-}" != "debian" ]]; then
    warn_msg "Streambot Touch currently only supports Debian."
    exit 1
  fi

  if [[ "${VERSION_CODENAME:-}" != "trixie" ]]; then
    warn_msg "Streambot Touch requires Debian 13 (Trixie)."
    warn_msg "Detected: ${PRETTY_NAME:-unknown}"
    exit 1
  fi

  ok_msg "Debian 13 (Trixie) detected"
}


questions() {
  title_msg "Welcome to the Streambot Touch kiosk installer."

  status_msg "Please enter your Streambot Touch config file"
  read -p "$cyan Config file (leave empty for $MCCONFIGFILE): $default" config_file

  if [[ "$config_file" != "" ]]; then
    MCCONFIGFILE="$config_file"
  fi

  ok_msg "Streambot Touch config file set: $MCCONFIGFILE"
}


setup_apt_dependencies() {
  status_msg "Install APT bootstrap dependencies"

  sudo apt update

  sudo apt-get -y install --no-install-recommends \
    ca-certificates \
    curl \
    debian-archive-keyring
}


setup_backports_repo() {
  status_msg "Enable Debian Trixie Backports"

  sudo tee /etc/apt/sources.list.d/debian-backports.sources >/dev/null <<'EOF'
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie-backports
Components: main
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

  sudo apt update

  ok_msg "Trixie Backports enabled"
}


setup_custom_apt_repo() {
  status_msg "Enable tludwig dev repo"

  curl -fsSL https://apt.tludwig.dev/install.sh | sh

  sudo apt update
}


install_packages() {
  status_msg "Install kiosk dependencies"

  sudo apt-get -y install --no-install-recommends \
    labwc \
    dbus-user-session \
    seatd \
    qt6-wayland \
    qml6-module-qtquick \
    qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts \
    qml6-module-qtwebsockets \
    libgl1-mesa-dri \
    libegl-mesa0 \
    libgles2 \
    swayidle \
    wtype \
    squeekboard \
    libglib2.0-bin

  status_msg "Install Quickshell from Trixie Backports"

  sudo apt-get -y install \
    quickshell/trixie-backports

  status_msg "Install Streambot Touch"

  sudo apt-get -y install \
    streambot-touch

  status_msg "Enable seatd service"

  sudo systemctl enable --now seatd
}


modify_user() {
  status_msg "Update user permissions"

  sudo usermod -aG video,render,input,tty "$USER"
  sudo loginctl enable-linger "$USER"
}


install_service() {
  if [[ -x "$SCRIPTPATH/generateService.sh" ]]; then
    "$SCRIPTPATH/generateService.sh" --app_config="$MCCONFIGFILE"
  else
    warn_msg "generateService.sh not found or not executable."
    exit 1
  fi
}


install_labwc_config() {
  if [[ -x "$SCRIPTPATH/installLabwcConfig.sh" ]]; then
    "$SCRIPTPATH/installLabwcConfig.sh" --app_config="$MCCONFIGFILE"
  else
    warn_msg "installLabwcConfig.sh not found or not executable."
    exit 1
  fi
}


install_networkmanager_polkit() {
  if [[ -x "$SCRIPTPATH/installNetworkManagerPolkit.sh" ]]; then
    "$SCRIPTPATH/installNetworkManagerPolkit.sh"
  else
    warn_msg "installNetworkManagerPolkit.sh not found or not executable."
    exit 1
  fi
}


check_distribution
questions
setup_apt_dependencies
setup_backports_repo
setup_custom_apt_repo
install_packages
modify_user
install_networkmanager_polkit
install_labwc_config
install_service

ok_msg "Installation finished. Reboot is recommended."