#!/usr/bin/env bash
# Builds the bootable NexOS live ISO using Debian live-build.

set -Eeuo pipefail
BUILD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$BUILD_SCRIPT_DIR/lib/common.sh"

require_cmd lb
require_cmd tee
require_cmd sha256sum
require_cmd find

ensure_dir "$ISO_DIR"
ensure_dir "$LOG_DIR"

log "Preparing fresh live-build configuration."
# Use bash explicitly so Windows/GitHub web uploads cannot break this by
# stripping Linux executable permissions from scripts. Use BUILD_SCRIPT_DIR
# because common.sh defines its own SCRIPT_DIR for the shared library folder.
bash "$BUILD_SCRIPT_DIR/02-init-live-build.sh"

log "Injecting Part 4 desktop polish and forced live login."

# Add Part 4 desktop/app packages after the base config is generated.
cat > "$LB_CONFIG_DIR/package-lists/40-nexos-desktop-polish.list.chroot" <<'PKGS'
# NexOS Part 4: desktop polish, beginner tools, and app defaults.
xfce4-whiskermenu-plugin
xfce4-power-manager
xfce4-goodies
arc-theme
papirus-icon-theme
fonts-dejavu
fonts-liberation
fonts-noto-core
fonts-noto-color-emoji
zenity
rofi
catfish
gparted
baobab
neofetch
fastfetch
pciutils
usbutils
lshw
inxi
geany
geany-plugins
meld
ristretto
vlc
libreoffice-writer
libreoffice-calc
libreoffice-impress
simple-scan
cups
system-config-printer
PKGS

# This hook runs inside the live filesystem and creates a nicer Windows-like XFCE layout.
cat > "$LB_CONFIG_DIR/hooks/normal/020-nexos-part4-desktop.hook.chroot" <<HOOK
#!/usr/bin/env bash
set -euo pipefail

LIVE_USERNAME="$LIVE_USERNAME"
LIVE_FULLNAME="$LIVE_FULLNAME"
LIVE_PASSWORD="$LIVE_USERNAME"

if ! id "\$LIVE_USERNAME" >/dev/null 2>&1; then
  useradd -m -s /bin/bash -c "\$LIVE_FULLNAME" "\$LIVE_USERNAME"
fi

echo "\$LIVE_USERNAME:\$LIVE_PASSWORD" | chpasswd
usermod -U "\$LIVE_USERNAME" 2>/dev/null || true

for group in sudo audio video plugdev netdev users cdrom lpadmin scanner bluetooth; do
  if getent group "\$group" >/dev/null 2>&1; then
    usermod -aG "\$group" "\$LIVE_USERNAME" || true
  fi
done

mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-nexos-live-autologin.conf <<LIGHTDM
[Seat:*]
autologin-user=$LIVE_USERNAME
autologin-user-timeout=0
autologin-session=xfce
user-session=xfce
greeter-session=lightdm-gtk-greeter
LIGHTDM

# Make the ISO easy to test even if autologin does not fire.
mkdir -p "/home/\$LIVE_USERNAME/Desktop" "/home/\$LIVE_USERNAME/.config/autostart" "/home/\$LIVE_USERNAME/.config/xfce4/xfconf/xfce-perchannel-xml" "/home/\$LIVE_USERNAME/.local/share/applications"
cat > "/home/\$LIVE_USERNAME/Desktop/README-NexOS-Login.txt" <<README
NexOS live login:
Username: $LIVE_USERNAME
Password: $LIVE_USERNAME

Autologin should start automatically. If the login screen appears, use the credentials above.
README

cat > /usr/local/bin/nexos-welcome <<'WELCOME'
#!/usr/bin/env bash
set -euo pipefail
zenity --info \
  --title="Welcome to NexOS" \
  --width=560 \
  --height=330 \
  --text="<b>Welcome to NexOS Origin</b>\n\nThis is the Part 4 desktop polish build.\n\nLogin: nexos / nexos\n\nIncluded starter tools:\n• File manager and archive tools\n• Firefox ESR\n• Geany code editor\n• LibreOffice basics\n• GParted, system info, and printer tools\n\nOpen Terminal and run: nexos-info" || true
WELCOME
chmod 0755 /usr/local/bin/nexos-welcome

cat > "/home/\$LIVE_USERNAME/.config/autostart/nexos-welcome.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Welcome
Exec=nexos-welcome
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP

cat > "/home/\$LIVE_USERNAME/Desktop/NexOS Welcome.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Welcome
Comment=Open the NexOS welcome screen
Exec=nexos-welcome
Icon=dialog-information
Terminal=false
Categories=System;
DESKTOP
chmod 0755 "/home/\$LIVE_USERNAME/Desktop/NexOS Welcome.desktop"

cat > "/home/\$LIVE_USERNAME/Desktop/File Manager.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=File Manager
Exec=thunar
Icon=system-file-manager
Terminal=false
Categories=System;FileManager;
DESKTOP
chmod 0755 "/home/\$LIVE_USERNAME/Desktop/File Manager.desktop"

cat > "/home/\$LIVE_USERNAME/Desktop/Code Editor.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Code Editor
Exec=geany
Icon=geany
Terminal=false
Categories=Development;
DESKTOP
chmod 0755 "/home/\$LIVE_USERNAME/Desktop/Code Editor.desktop"

cat > "/home/\$LIVE_USERNAME/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" <<'XML'
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

cat > "/home/\$LIVE_USERNAME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" <<'XML'
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
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="whiskermenu"/>
    <property name="plugin-2" type="string" value="tasklist"/>
    <property name="plugin-3" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-4" type="string" value="systray"/>
    <property name="plugin-5" type="string" value="pulseaudio"/>
    <property name="plugin-6" type="string" value="clock"/>
  </property>
</channel>
XML

cat > "/home/\$LIVE_USERNAME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="desktop-icons" type="empty">
    <property name="style" type="int" value="2"/>
  </property>
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitorVirtual1" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/nexos/nexos-origin.svg"/>
          <property name="image-style" type="int" value="5"/>
        </property>
      </property>
    </property>
  </property>
</channel>
XML

cat > /usr/local/bin/nexos-system-report <<'REPORT'
#!/usr/bin/env bash
set -euo pipefail
{
  echo "NexOS System Report"
  echo "==================="
  date
  echo
  nexos-info || true
  echo
  uname -a
  echo
  command -v fastfetch >/dev/null 2>&1 && fastfetch || true
} | less
REPORT
chmod 0755 /usr/local/bin/nexos-system-report

cat > /usr/share/applications/nexos-system-report.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS System Report
Comment=Show NexOS system information
Exec=xfce4-terminal --command=nexos-system-report
Icon=utilities-system-monitor
Terminal=false
Categories=System;
DESKTOP

# Copy current defaults into /etc/skel so future live user resets match.
mkdir -p /etc/skel
rsync -a "/home/\$LIVE_USERNAME/" /etc/skel/ || true
chown -R "\$LIVE_USERNAME:\$LIVE_USERNAME" "/home/\$LIVE_USERNAME"
chmod 0755 "/home/\$LIVE_USERNAME/Desktop" || true

if command -v systemctl >/dev/null 2>&1; then
  systemctl enable NetworkManager.service 2>/dev/null || true
  systemctl enable lightdm.service 2>/dev/null || true
  systemctl enable cups.service 2>/dev/null || true
fi
HOOK
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/020-nexos-part4-desktop.hook.chroot"

log "Starting live-build. This downloads Debian packages and may take a while."
log "Target ISO: $ARTIFACT_ISO"

pushd "$LIVE_BUILD_DIR" >/dev/null

# Keep the build log even if live-build fails.
BUILD_LOG="$LOG_DIR/live-build-part4.log"
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  lb build 2>&1 | tee "$BUILD_LOG"
else
  sudo lb build 2>&1 | tee "$BUILD_LOG"
fi

popd >/dev/null

candidate="$(find "$LIVE_BUILD_DIR" -maxdepth 1 -type f \( -name '*.iso' -o -name '*.hybrid.iso' \) -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2- || true)"
if [[ -z "$candidate" || ! -f "$candidate" ]]; then
  fail "live-build finished but no ISO file was found in $LIVE_BUILD_DIR. Check $BUILD_LOG"
fi

cp -f "$candidate" "$ARTIFACT_ISO"
sha256sum "$ARTIFACT_ISO" > "$ARTIFACT_ISO.sha256"

success "ISO built: $ARTIFACT_ISO"
success "Checksum: $ARTIFACT_ISO.sha256"
log "Run: make validate-iso"
log "Optional quick boot test: make qemu-test"
