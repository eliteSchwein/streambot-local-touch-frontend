#!/bin/bash
set -e

yellow=$(echo -en "\e[93m")
green=$(echo -en "\e[92m")
red=$(echo -en "\e[91m")
default=$(echo -en "\e[39m")

MCCONFIGFILE="/home/$(whoami)/streambot-touch.cfg"

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

cat > "$HOME/.local/bin/streambot-touch-squeekboard" <<'EOF_SCRIPT'
#!/bin/sh
set -eu

export GDK_BACKEND="${GDK_BACKEND:-wayland}"
export SQUEEKBOARD_LAYOUT="${SQUEEKBOARD_LAYOUT:-streambot}"

# Enable GNOME/GTK a11y OSK integration when gsettings is available.
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true 2>/dev/null || true

  # Keep the input source list minimal. This avoids extra/broken choices in
  # squeekboard's globe/layout selector on kiosk installs.
  gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us')]" 2>/dev/null || true
  gsettings set org.gnome.desktop.input-sources current 0 2>/dev/null || true
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

# Custom wide layout for Streambot Touch. It exposes letters, numbers and common
# symbols without relying on a phone-only layout.
cat > "$HOME/.local/share/squeekboard/keyboards/streambot.yaml" <<'EOF_LAYOUT'
---
outlines:
  default: { width: 44, height: 46 }
  small: { width: 36, height: 46 }
  wide: { width: 72, height: 46 }
  space: { width: 220, height: 46 }
  action: { width: 64, height: 46 }

views:
  base:
    - "q w e r t y u i o p"
    - "a s d f g h j k l"
    - "shift z x c v b n m backspace"
    - "symbols comma space period enter"
  shift:
    - "Q W E R T Y U I O P"
    - "A S D F G H J K L"
    - "shift z x c v b n m backspace"
    - "symbols comma space period enter"
  symbols:
    - "1 2 3 4 5 6 7 8 9 0"
    - "exclam at hash dollar percent caret amp asterisk parenleft parenright"
    - "minus underscore plus equal slash backslash colon semicolon quote doublequote"
    - "base comma space period enter"

buttons:
  shift:
    action: locking
    keysym: Shift_L
    outline: action
  symbols:
    action: set_view
    view: symbols
    label: "123#!"
    outline: action
  base:
    action: set_view
    view: base
    label: "ABC"
    outline: action
  backspace:
    keysym: BackSpace
    label: "⌫"
    outline: action
  enter:
    keysym: Return
    label: "Enter"
    outline: action
  space:
    keysym: space
    label: "Space"
    outline: space
  comma:
    keysym: comma
    label: ","
    outline: small
  period:
    keysym: period
    label: "."
    outline: small
  exclam: { text: "!", label: "!" }
  at: { text: "@", label: "@" }
  hash: { text: "#", label: "#" }
  dollar: { text: "$", label: "$" }
  percent: { text: "%", label: "%" }
  caret: { text: "^", label: "^" }
  amp: { text: "&", label: "&" }
  asterisk: { text: "*", label: "*" }
  parenleft: { text: "(", label: "(" }
  parenright: { text: ")", label: ")" }
  minus: { text: "-", label: "-" }
  underscore: { text: "_", label: "_" }
  plus: { text: "+", label: "+" }
  equal: { text: "=", label: "=" }
  slash: { text: "/", label: "/" }
  backslash: { text: "\\", label: "\\" }
  colon: { text: ":", label: ":" }
  semicolon: { text: ";", label: ";" }
  quote: { text: "'", label: "'" }
  doublequote: { text: '"', label: '"' }
EOF_LAYOUT

# Squeekboard can expose an "Emote"/emoji entry through the globe selector.
# On this kiosk that layout is not useful and can be broken, so override it with
# the same stable Streambot keyboard instead of letting users land on a bad view.
cp "$HOME/.local/share/squeekboard/keyboards/streambot.yaml" \
   "$HOME/.local/share/squeekboard/keyboards/emoji.yaml"

cat > "$HOME/.config/labwc/autostart" <<EOF_AUTOSTART
#!/bin/sh
export GDK_BACKEND=wayland
export GTK_IM_MODULE=wayland
export QT_IM_MODULE=wayland
export XMODIFIERS=@im=wayland
export SQUEEKBOARD_LAYOUT=streambot

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
	</keyboard>
</openbox_config>
EOF_RC

ok_msg "labwc + squeekboard config installed"
