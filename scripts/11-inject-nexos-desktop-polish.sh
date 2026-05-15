#!/usr/bin/env bash
# Injects NexOS desktop polish, shortcuts, and session helpers.
# Focused on Main and Security first.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

NEXOS_EDITION="${NEXOS_EDITION:-main}"
EDITION_LABEL="${EDITION_LABEL:-NexOS Main}"

ensure_dir "$LB_CONFIG_DIR/hooks/normal"

cat > "$LB_CONFIG_DIR/hooks/normal/050-nexos-desktop-polish.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail

LIVE_USERNAME="__LIVE_USERNAME__"
NEXOS_EDITION="__NEXOS_EDITION__"
EDITION_LABEL="__EDITION_LABEL__"

home_dir="/home/$LIVE_USERNAME"
mkdir -p "$home_dir/.config/xfce4/xfconf/xfce-perchannel-xml" "$home_dir/.config/autostart" "$home_dir/Desktop" /usr/local/bin /usr/share/applications /usr/share/nexos

cat > /usr/local/bin/nexos-run <<'RUNAPP'
#!/usr/bin/env bash
set -euo pipefail
cmd="$(zenity --entry --title="NexOS Run" --width=520 --text="Type a command, app name, or path to open:" || true)"
[[ -n "$cmd" ]] || exit 0
bash -lc "$cmd" >/tmp/nexos-run.log 2>&1 &
RUNAPP
chmod 0755 /usr/local/bin/nexos-run

cat > /usr/local/bin/nexos-power <<'POWER'
#!/usr/bin/env bash
set -euo pipefail
choice="$(zenity --list --title="NexOS Power" --width=420 --height=300 --print-column=1 --column="Action" --column="Description" \
  "Lock" "Lock the current session" \
  "Logout" "Log out of NexOS" \
  "Restart" "Restart the computer" \
  "Shutdown" "Power off the computer" || true)"
[[ -n "$choice" ]] || exit 0
case "$choice" in
  Lock) xflock4 >/dev/null 2>&1 & ;;
  Logout) xfce4-session-logout --logout >/dev/null 2>&1 & ;;
  Restart) xfce4-session-logout --reboot >/dev/null 2>&1 & ;;
  Shutdown) xfce4-session-logout --halt >/dev/null 2>&1 & ;;
esac
POWER
chmod 0755 /usr/local/bin/nexos-power

cat > /usr/local/bin/nexos-about <<'ABOUT'
#!/usr/bin/env bash
set -euo pipefail
info="$(nexos-info 2>/dev/null || true)"
zenity --info --title="About NexOS" --width=600 --height=360 --text="<b>NexOS</b>\n\nAn original Linux-based OS experience built with open-source foundations.\n\n$info\n\nCore commands:\n• nexos-control-center\n• nexos-code-editor\n• nexos-extractor\n• nexos-repair-tools\n• nexos-system-report" || true
ABOUT
chmod 0755 /usr/local/bin/nexos-about

cat > /usr/local/bin/nexos-help <<'HELP'
#!/usr/bin/env bash
set -euo pipefail
cat > /tmp/nexos-help.txt <<'TXT'
NexOS Quick Help
================

Login:
  Username: nexos
  Password: nexos

Core apps:
  nexos-control-center   Main NexOS settings/tools launcher
  nexos-code-editor      Open the best installed code editor
  nexos-extractor        Extract ZIP/7z/TAR archives
  nexos-repair-tools     Repair common desktop/session issues
  nexos-app-map          Show open-source foundations used by NexOS
  nexos-system-report    Show hardware/system info
  nexos-update-helper    Check live package updates
  nexos-run              Run a command from a small GUI
  nexos-power            Power/logout helper

Notes:
  This is a live ISO. Changes may reset after reboot until installer support is added.
TXT
if command -v mousepad >/dev/null 2>&1; then
  mousepad /tmp/nexos-help.txt >/dev/null 2>&1 &
else
  less /tmp/nexos-help.txt
fi
HELP
chmod 0755 /usr/local/bin/nexos-help

# XFCE panel: bottom taskbar style, menu, launchers, task list, tray, clock.
cat > "$home_dir/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=10;x=0;y=0"/>
      <property name="length" type="uint" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="size" type="uint" value="42"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="2"/>
        <value type="int" value="3"/>
        <value type="int" value="4"/>
        <value type="int" value="5"/>
        <value type="int" value="6"/>
        <value type="int" value="7"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="whiskermenu"/>
    <property name="plugin-2" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="nexos-control-center.desktop"/>
      </property>
    </property>
    <property name="plugin-3" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="nexos-code-editor.desktop"/>
      </property>
    </property>
    <property name="plugin-4" type="string" value="tasklist"/>
    <property name="plugin-5" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-6" type="string" value="systray"/>
    <property name="plugin-7" type="string" value="clock"/>
  </property>
</channel>
XML

cat > "$home_dir/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-keyboard-shortcuts" version="1.0">
  <property name="commands" type="empty">
    <property name="custom" type="empty">
      <property name="&lt;Primary&gt;&lt;Alt&gt;t" type="string" value="xfce4-terminal"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;c" type="string" value="nexos-control-center"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;e" type="string" value="nexos-code-editor"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;x" type="string" value="nexos-extractor"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;r" type="string" value="nexos-run"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;p" type="string" value="nexos-power"/>
    </property>
  </property>
</channel>
XML

cat > "$home_dir/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Arc-Dark"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Noto Sans 10"/>
    <property name="MonospaceFontName" type="string" value="DejaVu Sans Mono 10"/>
  </property>
</channel>
XML

make_desktop() {
  local path="$1" name="$2" comment="$3" exec_cmd="$4" icon="$5" cats="$6"
  cat > "$path" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Comment=$comment
Exec=$exec_cmd
Icon=$icon
Terminal=false
Categories=$cats
DESKTOP
}

make_desktop /usr/share/applications/nexos-run.desktop "NexOS Run" "Run a command or app" "nexos-run" "system-run" "Utility;"
make_desktop /usr/share/applications/nexos-power.desktop "NexOS Power" "Power and logout options" "nexos-power" "system-shutdown" "System;"
make_desktop /usr/share/applications/nexos-about.desktop "About NexOS" "About this NexOS build" "nexos-about" "help-about" "System;"
make_desktop /usr/share/applications/nexos-help.desktop "NexOS Help" "Open NexOS quick help" "nexos-help" "help-browser" "Documentation;System;"

for desktop in "NexOS Run" "NexOS Power" "About NexOS" "NexOS Help"; do
  case "$desktop" in
    "NexOS Run") src=/usr/share/applications/nexos-run.desktop ;;
    "NexOS Power") src=/usr/share/applications/nexos-power.desktop ;;
    "About NexOS") src=/usr/share/applications/nexos-about.desktop ;;
    "NexOS Help") src=/usr/share/applications/nexos-help.desktop ;;
  esac
  cp -f "$src" "$home_dir/Desktop/$desktop.desktop" || true
  chmod 0755 "$home_dir/Desktop/$desktop.desktop" || true
done

chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel
rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK

sed -i \
  -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" \
  -e "s/__NEXOS_EDITION__/$NEXOS_EDITION/g" \
  -e "s/__EDITION_LABEL__/$EDITION_LABEL/g" \
  "$LB_CONFIG_DIR/hooks/normal/050-nexos-desktop-polish.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/050-nexos-desktop-polish.hook.chroot"

success "Injected NexOS desktop polish for $NEXOS_EDITION."
