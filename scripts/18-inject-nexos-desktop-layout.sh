#!/usr/bin/env bash
# Builds a cleaner NexOS XFCE desktop layout.
# Goal: keep the layout style the user liked, but make it cleaner and flip the top panel sides.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

NEXOS_EDITION="${NEXOS_EDITION:-main}"
EDITION_LABEL="${EDITION_LABEL:-NexOS Main}"

ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"

cat > "$LB_CONFIG_DIR/package-lists/52-nexos-desktop-layout.list.chroot" <<'PKGS'
# NexOS cleaner desktop layout.
xfce4-whiskermenu-plugin
xfce4-appmenu-plugin
xfce4-pulseaudio-plugin
xfce4-statusnotifier-plugin
xfce4-datetime-plugin
xfce4-notifyd
papirus-icon-theme
arc-theme
PKGS

cat > "$LB_CONFIG_DIR/hooks/normal/120-nexos-desktop-layout.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

LIVE_USERNAME="__LIVE_USERNAME__"
NEXOS_EDITION="__NEXOS_EDITION__"
EDITION_LABEL="__EDITION_LABEL__"
home_dir="/home/$LIVE_USERNAME"

install_if_available() {
  local pkg="$1"
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    apt-get install -y --no-install-recommends "$pkg" || true
  fi
}

apt-get update || true
for pkg in xfce4-whiskermenu-plugin xfce4-pulseaudio-plugin xfce4-statusnotifier-plugin xfce4-datetime-plugin xfce4-notifyd papirus-icon-theme arc-theme; do
  install_if_available "$pkg"
done

mkdir -p \
  "$home_dir/Desktop" \
  "$home_dir/.config/autostart" \
  "$home_dir/.config/xfce4/xfconf/xfce-perchannel-xml" \
  "$home_dir/.config/xfce4/panel/launcher-30" \
  "$home_dir/.config/xfce4/panel/launcher-31" \
  "$home_dir/.config/xfce4/panel/launcher-32" \
  "$home_dir/.config/xfce4/panel/launcher-33" \
  "$home_dir/.config/xfce4/panel/launcher-34" \
  /usr/local/bin /usr/share/applications /usr/share/nexos

# Clean desktop launcher set. Keep the Home/File System/Trash defaults, then only the main NexOS shortcuts.
cat > /usr/local/bin/nexos-desktop-cleanup <<'CLEANUP'
#!/usr/bin/env bash
set -euo pipefail
desktop="$HOME/Desktop"
mkdir -p "$desktop" "$HOME/.local/share/nexos-hidden-desktop-launchers"
find "$desktop" -maxdepth 1 -type f -name '*.desktop' | while read -r file; do
  base="$(basename "$file")"
  case "$base" in
    "NexOS Control Center.desktop"|"NexOS Install Center.desktop"|"NexOS Dev Center.desktop"|"NexOS Startup Center.desktop"|"NexOS VM Display Help.desktop")
      chmod 0755 "$file" || true
      ;;
    *)
      mv -f "$file" "$HOME/.local/share/nexos-hidden-desktop-launchers/$base" 2>/dev/null || rm -f "$file"
      ;;
  esac
done
rm -f "$desktop/calamares-install.desktop" "$desktop/Install System.desktop" 2>/dev/null || true
CLEANUP
chmod 0755 /usr/local/bin/nexos-desktop-cleanup

# Re-copy only the clean visible NexOS desktop shortcuts.
copy_launcher() {
  local src="$1" dest="$2"
  [[ -f "$src" ]] || return 0
  cp -f "$src" "$home_dir/Desktop/$dest.desktop"
  chmod 0755 "$home_dir/Desktop/$dest.desktop" || true
}
copy_launcher /usr/share/applications/nexos-control-center.desktop "NexOS Control Center"
copy_launcher /usr/share/applications/nexos-install-center.desktop "NexOS Install Center"
copy_launcher /usr/share/applications/nexos-dev-center.desktop "NexOS Dev Center"
copy_launcher /usr/share/applications/nexos-startup-center.desktop "NexOS Startup Center"
copy_launcher /usr/share/applications/nexos-vm-display-help.desktop "NexOS VM Display Help"
HOME="$home_dir" /usr/local/bin/nexos-desktop-cleanup || true

# Dock launchers.
cat > "$home_dir/.config/xfce4/panel/launcher-30/nexos-control-center.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Control Center
Exec=nexos-control-center
Icon=nexos-control-center
Terminal=false
DESKTOP
cat > "$home_dir/.config/xfce4/panel/launcher-31/nexos-dev-center.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Dev Center
Exec=nexos-dev-center
Icon=nexos-dev-center
Terminal=false
DESKTOP
cat > "$home_dir/.config/xfce4/panel/launcher-32/nexos-install-center.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Install Center
Exec=nexos-install-center
Icon=nexos-install-center
Terminal=false
DESKTOP
cat > "$home_dir/.config/xfce4/panel/launcher-33/nexos-browser.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Browser
Exec=nexos-browser
Icon=web-browser
Terminal=false
DESKTOP
cat > "$home_dir/.config/xfce4/panel/launcher-34/thunar.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Files
Exec=thunar
Icon=system-file-manager
Terminal=false
DESKTOP

# Top panel is intentionally flipped:
# LEFT side = status/clock/session like the old right side.
# RIGHT side = separator + Applications menu.
# Bottom panel = centered dock-style launchers.
cat > "$home_dir/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <value type="int" value="2"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=6;x=0;y=0"/>
      <property name="length" type="uint" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="size" type="uint" value="30"/>
      <property name="background-style" type="uint" value="0"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="10"/>
        <value type="int" value="11"/>
        <value type="int" value="12"/>
        <value type="int" value="13"/>
        <value type="int" value="14"/>
        <value type="int" value="15"/>
      </property>
    </property>
    <property name="panel-2" type="empty">
      <property name="position" type="string" value="p=10;x=0;y=0"/>
      <property name="length" type="uint" value="32"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="size" type="uint" value="54"/>
      <property name="autohide-behavior" type="uint" value="0"/>
      <property name="background-style" type="uint" value="0"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="30"/>
        <value type="int" value="31"/>
        <value type="int" value="32"/>
        <value type="int" value="33"/>
        <value type="int" value="34"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-10" type="string" value="systray"/>
    <property name="plugin-11" type="string" value="pulseaudio"/>
    <property name="plugin-12" type="string" value="clock">
      <property name="digital-format" type="string" value="%Y-%m-%d  %H:%M"/>
    </property>
    <property name="plugin-13" type="string" value="actions"/>
    <property name="plugin-14" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-15" type="string" value="whiskermenu">
      <property name="button-title" type="string" value="Applications"/>
      <property name="button-icon" type="string" value="nexos-startup"/>
      <property name="show-button-title" type="bool" value="true"/>
    </property>
    <property name="plugin-30" type="string" value="launcher">
      <property name="items" type="array"><value type="string" value="nexos-control-center.desktop"/></property>
    </property>
    <property name="plugin-31" type="string" value="launcher">
      <property name="items" type="array"><value type="string" value="nexos-dev-center.desktop"/></property>
    </property>
    <property name="plugin-32" type="string" value="launcher">
      <property name="items" type="array"><value type="string" value="nexos-install-center.desktop"/></property>
    </property>
    <property name="plugin-33" type="string" value="launcher">
      <property name="items" type="array"><value type="string" value="nexos-browser.desktop"/></property>
    </property>
    <property name="plugin-34" type="string" value="launcher">
      <property name="items" type="array"><value type="string" value="thunar.desktop"/></property>
    </property>
  </property>
</channel>
XML

# Make windows, fonts, and icon labels cleaner.
cat > "$home_dir/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Arc-Dark"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Noto Sans 11"/>
    <property name="MonospaceFontName" type="string" value="DejaVu Sans Mono 11"/>
    <property name="ToolbarStyle" type="string" value="icons"/>
  </property>
</channel>
XML

cat > "$home_dir/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Arc-Dark"/>
    <property name="title_font" type="string" value="Noto Sans Bold 10"/>
    <property name="button_layout" type="string" value="O|HMC"/>
    <property name="workspace_count" type="int" value="2"/>
  </property>
</channel>
XML

cat > "$home_dir/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="desktop-icons" type="empty">
    <property name="style" type="int" value="2"/>
    <property name="icon-size" type="uint" value="58"/>
    <property name="font-size" type="double" value="11.000000"/>
    <property name="show-thumbnails" type="bool" value="true"/>
  </property>
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/nexos/nexos-default.png"/>
          <property name="image-style" type="int" value="5"/>
        </property>
      </property>
    </property>
  </property>
</channel>
XML

cat > /usr/local/bin/nexos-desktop-layout-reset <<'RESET'
#!/usr/bin/env bash
set -euo pipefail
nexos-desktop-cleanup || true
xfce4-panel --restart >/dev/null 2>&1 &
notify-send "NexOS" "Desktop layout refreshed" 2>/dev/null || true
RESET
chmod 0755 /usr/local/bin/nexos-desktop-layout-reset

cat > "$home_dir/.config/autostart/nexos-desktop-cleanup.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Desktop Cleanup
Exec=sh -c 'sleep 2; nexos-desktop-cleanup; xfce4-panel --restart >/dev/null 2>&1 || true'
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP

cat > /usr/share/applications/nexos-desktop-layout-reset.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Desktop Layout Reset
Comment=Refresh the NexOS desktop layout
Exec=nexos-desktop-layout-reset
Icon=nexos-control-center
Terminal=false
Categories=Settings;System;
DESKTOP

cat >> /usr/share/nexos/app-map.txt <<'APPMAP_APPEND'

Desktop layout:
- Flipped top bar: status/clock/session controls on the left, Applications menu on the right.
- Center dock: Control Center, Dev Center, Install Center, Browser, and Files.
- Clean desktop: only major NexOS shortcuts stay visible.
- Layout reset command: nexos-desktop-layout-reset.
APPMAP_APPEND

chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel
rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK

sed -i \
  -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" \
  -e "s/__NEXOS_EDITION__/$NEXOS_EDITION/g" \
  -e "s/__EDITION_LABEL__/$EDITION_LABEL/g" \
  "$LB_CONFIG_DIR/hooks/normal/120-nexos-desktop-layout.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/120-nexos-desktop-layout.hook.chroot"

success "Injected cleaner NexOS desktop layout for $NEXOS_EDITION."
