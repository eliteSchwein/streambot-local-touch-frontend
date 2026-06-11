#!/bin/bash
set -e

yellow=$(echo -en "\e[93m")
green=$(echo -en "\e[92m")
red=$(echo -en "\e[91m")
default=$(echo -en "\e[39m")

MCCONFIGFILE="/home/$(whoami)/streambot-touch.cfg"
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

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

status_msg "Installing labwc autostart, squeekboard and config"

mkdir -p "$HOME/.config/labwc"
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/share/squeekboard/keyboards"

# Repair cleanup: remove the isolated layout dirs from the broken hardlimit attempt.
# We intentionally do NOT set XDG_DATA_HOME/XDG_DATA_DIRS for squeekboard anymore,
# because that can hide required system resources and break the keyboard completely.
rm -rf "$HOME/.local/share/streambot-touch-squeekboard-data"
rm -rf "$HOME/.local/share/streambot-touch-squeekboard-home"

cat > "$HOME/.local/bin/streambot-touch-squeekboard" <<'EOF_SCRIPT'
#!/bin/sh
set -eu

export GDK_BACKEND="${GDK_BACKEND:-wayland}"

# Enable GNOME/GTK a11y OSK integration when gsettings is available.
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true 2>/dev/null || true

  # Globe picker entries. First entry is the default.
  # Keep the OSK picker limited to these two real layouts:
  # us+intl = US International, de = German QWERTZ.
  gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us+intl'), ('xkb', 'de')]" 2>/dev/null || true
  gsettings set org.gnome.desktop.input-sources current 0 2>/dev/null || true

  # Clear cached / remembered extra sources where available, so broken built-in
  # emoji/emote/terminal layouts do not come back through the globe picker.
  gsettings set org.gnome.desktop.input-sources mru-sources "[('xkb', 'us+intl'), ('xkb', 'de')]" 2>/dev/null || true
  gsettings set org.gnome.desktop.input-sources show-all-sources false 2>/dev/null || true
fi

start_squeekboard() {
  if ! pgrep -x squeekboard >/dev/null 2>&1; then
    squeekboard >/tmp/streambot-touch-squeekboard.log 2>&1 &
    sleep 1
  fi
}

start_squeekboard

# Do NOT force SetVisible=true here. Squeekboard should stay running in the
# background and let the compositor / focused GTK input decide visibility.
# Start hidden so it does not cover the kiosk until an input field is focused.
if command -v gdbus >/dev/null 2>&1; then
  gdbus call --session \
    --dest sm.puri.OSK0 \
    --object-path /sm/puri/OSK0 \
    --method sm.puri.OSK0.SetVisible false >/dev/null 2>&1 || true
fi

while true; do
  start_squeekboard
  sleep 5
done
EOF_SCRIPT

chmod +x "$HOME/.local/bin/streambot-touch-squeekboard"

# Install keyboard layouts from ./keyboard_layouts instead of embedding them
# in this installer. This keeps the script flexible: add/edit YAML files there
# and re-run the installer.
LAYOUT_SOURCE_DIR="$SCRIPTPATH/keyboard_layouts"
LAYOUT_TARGET_DIR="$HOME/.local/share/squeekboard/keyboards"

if [[ ! -d "$LAYOUT_SOURCE_DIR" ]]; then
  warn_msg "Missing keyboard layout folder: $LAYOUT_SOURCE_DIR"
  warn_msg "Create it next to this script and put your *.yaml layouts in there."
  exit 1
fi

if ! find "$LAYOUT_SOURCE_DIR" -maxdepth 1 -type f -name '*.yaml' | grep -q .; then
  warn_msg "No *.yaml keyboard layouts found in: $LAYOUT_SOURCE_DIR"
  exit 1
fi

status_msg "Installing squeekboard keyboard layouts from $LAYOUT_SOURCE_DIR"
mkdir -p "$LAYOUT_TARGET_DIR"
find "$LAYOUT_TARGET_DIR" -maxdepth 1 -type f -name '*.yaml' -delete
cp "$LAYOUT_SOURCE_DIR"/*.yaml "$LAYOUT_TARGET_DIR"/

# Required picker layouts. Keep US International as default and German as option.
if [[ ! -f "$LAYOUT_TARGET_DIR/us+intl.yaml" ]]; then
  warn_msg "Missing required layout: keyboard_layouts/us+intl.yaml"
  exit 1
fi

if [[ ! -f "$LAYOUT_TARGET_DIR/de.yaml" ]]; then
  warn_msg "Missing required layout: keyboard_layouts/de.yaml"
  exit 1
fi

# Compatibility aliases for how squeekboard may resolve XKB names / old config.
cp "$LAYOUT_TARGET_DIR/us+intl.yaml" "$LAYOUT_TARGET_DIR/us.yaml"
cp "$LAYOUT_TARGET_DIR/us+intl.yaml" "$LAYOUT_TARGET_DIR/streambot.yaml"
cp "$LAYOUT_TARGET_DIR/us+intl.yaml" "$LAYOUT_TARGET_DIR/streambot-us.yaml"
cp "$LAYOUT_TARGET_DIR/de.yaml" "$LAYOUT_TARGET_DIR/streambot-de.yaml"

# Blacklist / shadow broken special keyboards. Some squeekboard versions still
# expose these through the globe picker or internal layout switching. By placing
# sane local files with the same names, selecting one falls back to US International
# instead of the broken emoji/emote/terminal boards.
for blocked_layout in \
  emoji \
  emojis \
  emote \
  emotes \
  terminal \
  terminal-us \
  us+terminal \
  us-terminal
do
  cp "$LAYOUT_TARGET_DIR/us+intl.yaml" "$LAYOUT_TARGET_DIR/${blocked_layout}.yaml"
done

cat > "$HOME/.config/labwc/autostart" <<EOF_AUTOSTART
#!/bin/sh
export GDK_BACKEND=wayland
export GTK_IM_MODULE=wayland
export QT_IM_MODULE=wayland
export XMODIFIERS=@im=wayland

swayidle -w \\
  timeout 2 'wtype -M alt -M logo -k h -m logo -m alt' &

exec sh -c 'sleep 0.25; wtype -M alt -M logo -k h -m logo -m alt' &

# Start squeekboard in auto-show mode. It appears when a text input is focused.
exec "$HOME/.local/bin/streambot-touch-squeekboard" &

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

ok_msg "labwc + squeekboard config installed"
