#!/usr/bin/env bash
# Builds a bootable NexOS live ISO using Debian live-build.
# Editions:
#   main     = normal NexOS desktop
#   creator  = NexOS desktop plus open-source creative tools such as Blender
#   security = NexOS desktop plus optional security-center tools

set -Eeuo pipefail
BUILD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$BUILD_SCRIPT_DIR/lib/common.sh"

require_cmd lb
require_cmd tee
require_cmd sha256sum
require_cmd find
require_cmd sed

NEXOS_EDITION="${NEXOS_EDITION:-main}"
case "$NEXOS_EDITION" in
  main|creator|security) ;;
  *) fail "Invalid NEXOS_EDITION='$NEXOS_EDITION'. Use: main, creator, or security" ;;
esac

BASE_ISO_NAME="${ISO_IMAGE_NAME%.iso}"
case "$NEXOS_EDITION" in
  main)
    OUTPUT_ISO="$ARTIFACT_ISO"
    EDITION_LABEL="NexOS Main"
    ;;
  creator)
    OUTPUT_ISO="$ISO_DIR/${BASE_ISO_NAME}-creator.iso"
    EDITION_LABEL="NexOS Creator"
    ;;
  security)
    OUTPUT_ISO="$ISO_DIR/${BASE_ISO_NAME}-security.iso"
    EDITION_LABEL="NexOS Security"
    ;;
esac

ensure_dir "$ISO_DIR"
ensure_dir "$LOG_DIR"

log "Building edition: $NEXOS_EDITION"
log "Preparing fresh live-build configuration."
if [[ -d "$LIVE_BUILD_DIR/config" ]]; then
  (cd "$LIVE_BUILD_DIR" && lb clean --purge >/dev/null 2>&1 || true)
fi
bash "$BUILD_SCRIPT_DIR/02-init-live-build.sh"

log "Injecting $EDITION_LABEL packages and NexOS integration."

cat > "$LB_CONFIG_DIR/package-lists/40-nexos-common-tools.list.chroot" <<'PKGS'
# NexOS common open-source desktop tools.
zenity
catfish
geany
meld
vlc
libreoffice-writer
libreoffice-calc
libreoffice-impress
cups
system-config-printer
fonts-noto-core
fonts-noto-color-emoji
papirus-icon-theme
arc-theme
PKGS

if [[ "$NEXOS_EDITION" == "creator" ]]; then
  cat > "$LB_CONFIG_DIR/package-lists/50-nexos-creator-tools.list.chroot" <<'PKGS'
# NexOS Creator edition open-source tools.
blender
gimp
inkscape
krita
audacity
kdenlive
obs-studio
ffmpeg
lmms
ardour
handbrake
PKGS
fi

if [[ "$NEXOS_EDITION" == "security" ]]; then
  cat > "$LB_CONFIG_DIR/package-lists/50-nexos-security-tools.list.chroot" <<'PKGS'
# NexOS Security edition open-source tools.
ufw
apparmor
apparmor-utils
auditd
aide
bubblewrap
firejail
lynis
clamav
clamav-freshclam
rkhunter
PKGS
fi

cat > "$LB_CONFIG_DIR/hooks/normal/020-nexos-edition-integration.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

LIVE_USERNAME="__LIVE_USERNAME__"
LIVE_FULLNAME="__LIVE_FULLNAME__"
LIVE_PASSWORD="__LIVE_USERNAME__"
NEXOS_EDITION="__NEXOS_EDITION__"
EDITION_LABEL="__EDITION_LABEL__"

install_if_available() {
  local pkg="$1"
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    apt-get install -y --no-install-recommends "$pkg" || true
  fi
}

apt-get update || true
for pkg in xfce4-whiskermenu-plugin xfce4-power-manager xfce4-goodies rofi baobab fastfetch neofetch pciutils usbutils lshw inxi geany-plugins gparted simple-scan; do
  install_if_available "$pkg"
done

if [[ "$NEXOS_EDITION" == "creator" ]]; then
  for pkg in blender gimp inkscape krita audacity kdenlive obs-studio ffmpeg lmms ardour handbrake; do
    install_if_available "$pkg"
  done
fi

if [[ "$NEXOS_EDITION" == "security" ]]; then
  for pkg in openscap-scanner scap-security-guide; do
    install_if_available "$pkg"
  done
fi

if ! id "$LIVE_USERNAME" >/dev/null 2>&1; then
  useradd -m -s /bin/bash -c "$LIVE_FULLNAME" "$LIVE_USERNAME"
fi

echo "$LIVE_USERNAME:$LIVE_PASSWORD" | chpasswd
usermod -U "$LIVE_USERNAME" 2>/dev/null || true
for group in sudo audio video plugdev netdev users cdrom lpadmin scanner bluetooth; do
  getent group "$group" >/dev/null 2>&1 && usermod -aG "$group" "$LIVE_USERNAME" || true
done

mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-nexos-live-autologin.conf <<LIGHTDM
[Seat:*]
autologin-user=__LIVE_USERNAME__
autologin-user-timeout=0
autologin-session=xfce
user-session=xfce
greeter-session=lightdm-gtk-greeter
LIGHTDM

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
  command -v fastfetch >/dev/null && fastfetch || true
  command -v neofetch >/dev/null && neofetch || true
} | less
REPORT
chmod 0755 /usr/local/bin/nexos-system-report

cat > /usr/local/bin/nexos-studio <<'STUDIO'
#!/usr/bin/env bash
set -euo pipefail
apps=(
  "Blender|blender|3D modeling, animation, rendering"
  "GIMP|gimp|Image editing"
  "Inkscape|inkscape|Vector graphics"
  "Krita|krita|Digital painting"
  "Audacity|audacity|Audio editing"
  "Kdenlive|kdenlive|Video editing"
  "OBS Studio|obs|Recording and streaming"
  "VLC|vlc|Media playback"
)
menu_items=()
for row in "${apps[@]}"; do
  IFS='|' read -r name cmd desc <<< "$row"
  command -v "$cmd" >/dev/null 2>&1 && menu_items+=("$name" "$desc")
done
if (( ${#menu_items[@]} == 0 )); then
  zenity --info --title="NexOS Studio" --text="No studio apps are installed in this edition yet." || true
  exit 0
fi
choice="$(zenity --list --title="NexOS Studio" --width=650 --height=420 --column="App" --column="Purpose" "${menu_items[@]}" || true)"
[[ -n "$choice" ]] || exit 0
case "$choice" in
  Blender) blender >/dev/null 2>&1 & ;;
  GIMP) gimp >/dev/null 2>&1 & ;;
  Inkscape) inkscape >/dev/null 2>&1 & ;;
  Krita) krita >/dev/null 2>&1 & ;;
  Audacity) audacity >/dev/null 2>&1 & ;;
  Kdenlive) kdenlive >/dev/null 2>&1 & ;;
  "OBS Studio") obs >/dev/null 2>&1 & ;;
  VLC) vlc >/dev/null 2>&1 & ;;
esac
STUDIO
chmod 0755 /usr/local/bin/nexos-studio

if [[ "$NEXOS_EDITION" == "security" ]]; then
  echo Basic > /etc/nexos-security-profile
  cat > /usr/local/bin/nexos-security-center <<'SECURITY'
#!/usr/bin/env bash
set -euo pipefail
pause(){ read -rp "Press Enter to continue..." _; }
header(){ clear || true; echo "NexOS Security Center"; echo "====================="; echo; }
status(){ header; echo "Profile: $(cat /etc/nexos-security-profile 2>/dev/null || echo Basic)"; echo; command -v ufw >/dev/null && sudo ufw status || true; echo; command -v aa-status >/dev/null && sudo aa-status || true; pause; }
while true; do header; echo "1) Show security status"; echo "2) Exit"; read -rp "Choose: " c; case "$c" in 1) status;; 2) exit 0;; esac; done
SECURITY
  chmod 0755 /usr/local/bin/nexos-security-center
fi

cat > /usr/local/bin/nexos-welcome <<'WELCOME'
#!/usr/bin/env bash
set -euo pipefail
EDITION="__EDITION_LABEL__"
case "__NEXOS_EDITION__" in
  creator) EXTRA="Creator edition integrates open-source creative apps for NexOS. Try: nexos-studio" ;;
  security) EXTRA="Security edition tools are included. Try: nexos-security-center" ;;
  *) EXTRA="This is the clean main NexOS edition. Creator and security stacks are separate builds." ;;
esac
zenity --info --title="Welcome to NexOS" --width=650 --height=390 --text="<b>Welcome to $EDITION</b>\n\nThis is your own NexOS operating system. Open-source apps are integrated as NexOS tools and launchers.\n\nLogin: nexos / nexos\n\n$EXTRA\n\nTry:\n  nexos-info\n  nexos-system-report\n  nexos-studio" || true
WELCOME
chmod 0755 /usr/local/bin/nexos-welcome

mkdir -p "/home/$LIVE_USERNAME/Desktop" "/home/$LIVE_USERNAME/.config/autostart" "/home/$LIVE_USERNAME/.config/xfce4/xfconf/xfce-perchannel-xml"
cat > "/home/$LIVE_USERNAME/Desktop/README-NexOS-Login.txt" <<README
NexOS live login:
Username: $LIVE_USERNAME
Password: $LIVE_PASSWORD
Edition: $EDITION_LABEL
README

cat > "/home/$LIVE_USERNAME/.config/autostart/nexos-welcome.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Welcome
Exec=nexos-welcome
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP

cat > "/home/$LIVE_USERNAME/Desktop/NexOS Welcome.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Welcome
Exec=nexos-welcome
Icon=dialog-information
Terminal=false
Categories=System;
DESKTOP
chmod 0755 "/home/$LIVE_USERNAME/Desktop/NexOS Welcome.desktop"

cat > "/home/$LIVE_USERNAME/Desktop/NexOS Studio.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Studio
Exec=nexos-studio
Icon=applications-graphics
Terminal=false
Categories=Graphics;AudioVideo;
DESKTOP
chmod 0755 "/home/$LIVE_USERNAME/Desktop/NexOS Studio.desktop"

cat > "/home/$LIVE_USERNAME/Desktop/File Manager.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=File Manager
Exec=thunar
Icon=system-file-manager
Terminal=false
Categories=System;FileManager;
DESKTOP
chmod 0755 "/home/$LIVE_USERNAME/Desktop/File Manager.desktop"

cat > "/home/$LIVE_USERNAME/Desktop/Code Editor.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Code Editor
Exec=geany
Icon=geany
Terminal=false
Categories=Development;
DESKTOP
chmod 0755 "/home/$LIVE_USERNAME/Desktop/Code Editor.desktop"

cat > /usr/share/applications/nexos-studio.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Studio
Exec=nexos-studio
Icon=applications-graphics
Terminal=false
Categories=Graphics;AudioVideo;
DESKTOP

cat > /usr/share/applications/nexos-system-report.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS System Report
Exec=xfce4-terminal --command=nexos-system-report
Icon=utilities-system-monitor
Terminal=false
Categories=System;
DESKTOP

if [[ "$NEXOS_EDITION" == "security" ]]; then
  cat > "/home/$LIVE_USERNAME/Desktop/NexOS Security Center.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Security Center
Exec=xfce4-terminal --command=nexos-security-center
Icon=security-high
Terminal=false
Categories=System;Security;
DESKTOP
  chmod 0755 "/home/$LIVE_USERNAME/Desktop/NexOS Security Center.desktop"
fi

cat > "/home/$LIVE_USERNAME/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Arc-Dark"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
  </property>
</channel>
XML

chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "/home/$LIVE_USERNAME"
mkdir -p /etc/skel
rsync -a "/home/$LIVE_USERNAME/" /etc/skel/ || true

if command -v systemctl >/dev/null 2>&1; then
  systemctl enable NetworkManager.service 2>/dev/null || true
  systemctl enable lightdm.service 2>/dev/null || true
  systemctl enable cups.service 2>/dev/null || true
  if [[ "$NEXOS_EDITION" == "security" ]]; then
    systemctl enable apparmor.service 2>/dev/null || true
    systemctl enable auditd.service 2>/dev/null || true
  fi
fi
HOOK

sed -i \
  -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" \
  -e "s/__LIVE_FULLNAME__/$LIVE_FULLNAME/g" \
  -e "s/__NEXOS_EDITION__/$NEXOS_EDITION/g" \
  -e "s/__EDITION_LABEL__/$EDITION_LABEL/g" \
  "$LB_CONFIG_DIR/hooks/normal/020-nexos-edition-integration.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/020-nexos-edition-integration.hook.chroot"

log "Starting live-build. This downloads Debian packages and may take a while."
log "Target ISO: $OUTPUT_ISO"

pushd "$LIVE_BUILD_DIR" >/dev/null
BUILD_LOG="$LOG_DIR/live-build-$NEXOS_EDITION.log"
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

cp -f "$candidate" "$OUTPUT_ISO"
sha256sum "$OUTPUT_ISO" > "$OUTPUT_ISO.sha256"

success "ISO built: $OUTPUT_ISO"
success "Checksum: $OUTPUT_ISO.sha256"
log "Run: NEXOS_EDITION=$NEXOS_EDITION make validate-iso"
