#!/bin/bash
set -euo pipefail

green=$(echo -en "\e[92m")
yellow=$(echo -en "\e[93m")
red=$(echo -en "\e[91m")
default=$(echo -en "\e[39m")

status_msg(){ echo; echo -e "${yellow}###### $1${default}"; }
ok_msg(){ echo -e "${green}>>>>>> $1${default}"; }
warn_msg(){ echo -e "${red}$1${default}"; }

if [[ ${UID} == '0' ]]; then
  warn_msg "You can't run this script as root. Run it as the target user; sudo is used where required."
  exit 1
fi

if command -v matugen >/dev/null 2>&1; then
  ok_msg "Matugen already installed: $(matugen --version 2>/dev/null || command -v matugen)"
  exit 0
fi

if [[ ! -r /etc/os-release ]]; then
  warn_msg "Unable to detect the operating system."
  exit 1
fi

. /etc/os-release

if [[ "${ID:-}" != "debian" || "${VERSION_CODENAME:-}" != "trixie" ]]; then
  warn_msg "Automatic Matugen installation currently supports Debian 13 (Trixie) only."
  warn_msg "Detected: ${PRETTY_NAME:-unknown}"
  exit 1
fi

status_msg "Install Matugen repository prerequisites"
sudo apt-get update
sudo apt-get -y install --no-install-recommends \
  ca-certificates \
  curl \
  gpg

status_msg "Enable DankLinux Matugen repository"
sudo install -d -m 0755 /etc/apt/keyrings

key_tmp="$(mktemp)"
trap 'rm -f "$key_tmp"' EXIT

curl -fsSL \
  https://download.opensuse.org/repositories/home:/AvengeMedia:/danklinux/Debian_13/Release.key \
  -o "$key_tmp"

sudo gpg --dearmor --yes \
  -o /etc/apt/keyrings/danklinux.gpg \
  "$key_tmp"

sudo chmod 0644 /etc/apt/keyrings/danklinux.gpg

sudo tee /etc/apt/sources.list.d/danklinux.sources >/dev/null <<'EOF_REPO'
Types: deb
URIs: https://download.opensuse.org/repositories/home:/AvengeMedia:/danklinux/Debian_13/
Suites: /
Signed-By: /etc/apt/keyrings/danklinux.gpg
EOF_REPO

sudo apt-get update

if ! apt-cache show matugen >/dev/null 2>&1; then
  warn_msg "The configured repository does not currently expose a matugen package for this system."
  warn_msg "Streambot Touch can still run with its built-in fallback colors."
  exit 1
fi

status_msg "Install Matugen"
sudo apt-get -y install --no-install-recommends matugen

if ! command -v matugen >/dev/null 2>&1; then
  warn_msg "Matugen was installed but is not available in PATH."
  exit 1
fi

ok_msg "Matugen installed: $(matugen --version 2>/dev/null || command -v matugen)"
