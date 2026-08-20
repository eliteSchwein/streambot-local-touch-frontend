#!/bin/bash
set -e

yellow=$(echo -en "\e[93m")
green=$(echo -en "\e[92m")
red=$(echo -en "\e[91m")
default=$(echo -en "\e[39m")

MCCONFIGFILE="/home/$(whoami)/.config/streambot/streambot-touch.cfg"

status_msg(){ echo; echo -e "${yellow}###### $1${default}"; }
ok_msg(){ echo -e "${green}>>>>>> $1${default}"; }
warn_msg(){ echo -e "${red} $1${default}"; }

for ARGUMENT in "$@"; do
  KEY=$(echo "$ARGUMENT" | cut -f1 -d=)
  VALUE=$(echo "$ARGUMENT" | cut -f2- -d=)

  case "$KEY" in
    --config_path|--app_config)
      MCCONFIGFILE="${VALUE}"
      ;;
  esac
done

if [[ ${UID} == '0' ]]; then
  warn_msg "You can't run this script as root!"
  exit 1
fi

status_msg "Installing labwc autostart and config"

mkdir -p "$HOME/.config/labwc"
mkdir -p "$HOME/.local/bin"

if [[ -f "$SCRIPTPATH/helper/power_key_listener.py" ]]; then
  install -m 0755     "$SCRIPTPATH/helper/power_key_listener.py"     "$HOME/.local/bin/streambot-touch-power-key-listener"
fi

# Clean up files left behind by older Squeekboard-based installs.
rm -f "$HOME/.local/bin/streambot-touch-squeekboard"
rm -rf "$HOME/.local/share/streambot-touch-squeekboard-data"
rm -rf "$HOME/.local/share/streambot-touch-squeekboard-home"

cat > "$HOME/.config/labwc/autostart" <<EOF_AUTOSTART
#!/bin/sh

# Hide/warp the pointer shortly after startup and again after inactivity.
swayidle -w \\
  timeout 2 "sh -c 'wtype -M alt -M logo -k h -m logo -m alt'" &

sh -c 'sleep 0.25; wtype -M alt -M logo -k h -m logo -m alt' &

# Grab the real Linux KEY_POWER input device directly. This mirrors the
# old Tauri backend's EVIOCGRAB behavior and avoids compositor key mapping.
if [ -x /usr/lib/streambot-touch/power-key-listener ]; then
  /usr/lib/streambot-touch/power-key-listener &
elif [ -x "$HOME/.local/bin/streambot-touch-power-key-listener" ]; then
  "$HOME/.local/bin/streambot-touch-power-key-listener" &
fi

# Qt Virtual Keyboard is configured by /usr/bin/streambot-touch.
exec /usr/bin/streambot-touch --app-config "$MCCONFIGFILE"
EOF_AUTOSTART

chmod +x "$HOME/.config/labwc/autostart"

cat > "$HOME/.config/labwc/rc.xml" <<'EOF_RC'
<?xml version="1.0"?>
<openbox_config>
  <keyboard>
    <keybind key="A-W-h">
      <action name="HideCursor" />
      <action name="WarpCursor" x="-1" y="-1" />
    </keybind>

    <keybind key="XF86AudioNext">
      <action name="Execute" command="playerctl next" />
    </keybind>

    <keybind key="XF86AudioPause">
      <action name="Execute" command="playerctl play-pause" />
    </keybind>

    <keybind key="XF86AudioPlay">
      <action name="Execute" command="playerctl play-pause" />
    </keybind>

    <keybind key="XF86AudioPrev">
      <action name="Execute" command="playerctl previous" />
    </keybind>
  </keyboard>
</openbox_config>
EOF_RC

ok_msg "labwc config installed"
