#!/usr/bin/env bash
# Builds a bootable NexOS live ISO using Debian live-build.
# Editions:
#   main     = clean NexOS desktop
#   tools    = NexOS desktop plus broad open-source tool packs
#   creator  = alias-style creator build kept for older workflow targets
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
  main|tools|creator|security) ;;
  *) fail "Invalid NEXOS_EDITION='$NEXOS_EDITION'. Use: main, tools, creator, or security" ;;
esac

BASE_ISO_NAME="${ISO_IMAGE_NAME%.iso}"
case "$NEXOS_EDITION" in
  main)
    OUTPUT_ISO="$ARTIFACT_ISO"
    EDITION_LABEL="NexOS Main"
    ;;
  tools)
    OUTPUT_ISO="$ISO_DIR/${BASE_ISO_NAME}-tools.iso"
    EDITION_LABEL="NexOS Tools"
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

log "Injecting $EDITION_LABEL packages and NexOS app integration."

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

# Always try to improve the base desktop, but never let optional packages break the ISO.
for pkg in xfce4-whiskermenu-plugin xfce4-power-manager xfce4-goodies rofi baobab fastfetch neofetch pciutils usbutils lshw inxi geany-plugins gparted simple-scan; do
  install_if_available "$pkg"
done

# Broad NexOS open-source tool pack. This is not just creator apps: it covers creative,
# development, system, productivity, network, education, and utility categories.
if [[ "$NEXOS_EDITION" == "tools" || "$NEXOS_EDITION" == "creator" ]]; then
  for pkg in \
    blender gimp inkscape krita audacity kdenlive obs-studio ffmpeg lmms ardour handbrake \
    freecad openscad sweethome3d darktable rawtherapee scribus fontforge \
    kate codeblocks qtcreator python3-pip python3-tk nodejs npm rustc cargo openjdk-21-jdk \
    gitg sqlitebrowser dbeaver dbeaver-ce \
    gnome-disk-utility filezilla remmina thunderbird keepassxc flameshot \
    virtualbox-guest-x11 qemu-guest-agent spice-vdagent \
    godot3 love stellarium octave maxima gnuplot qalculate-gtk; do
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

cat > /usr/local/bin/nexos-toolbox <<'TOOLBOX'
#!/usr/bin/env bash
set -euo pipefail
apps=(
  "3D / Blender|Blender|blender|3D modeling, animation, rendering"
  "3D / CAD|FreeCAD|freecad|CAD modeling"
  "3D / CAD|OpenSCAD|openscad|Script-based CAD modeling"
  "Graphics|GIMP|gimp|Image editing"
  "Graphics|Inkscape|inkscape|Vector graphics"
  "Graphics|Krita|krita|Digital painting"
  "Media|Audacity|audacity|Audio editing"
  "Media|Kdenlive|kdenlive|Video editing"
  "Media|OBS Studio|obs|Recording and streaming"
  "Media|VLC|vlc|Media playback"
  "Development|Geany|geany|Lightweight code editor"
  "Development|Kate|kate|Advanced text editor"
  "Development|Code::Blocks|codeblocks|C/C++ IDE"
  "Development|Qt Creator|qtcreator|Qt/C++ IDE"
  "Development|SQLite Browser|sqlitebrowser|SQLite database editor"
  "Files / Network|FileZilla|filezilla|FTP/SFTP file transfer"
  "Files / Network|Remmina|remmina|Remote desktop client"
  "Productivity|LibreOffice Writer|libreoffice|Documents"
  "Productivity|Thunderbird|thunderbird|Email client"
  "Security / Passwords|KeePassXC|keepassxc|Password manager"
  "System|GParted|gparted|Disk partition editor"
  "System|Disk Utility|gnome-disks|Disk utility"
  "Education|Stellarium|stellarium|Planetarium"
  "Education|Octave|octave|Math/science computing"
)
menu_items=()
for row in "${apps[@]}"; do
  IFS='|' read -r category name cmd desc <<< "$row"
  command -v "$cmd" >/dev/null 2>&1 && menu_items+=("$category" "$name" "$desc")
done
if (( ${#menu_items[@]} == 0 )); then
  zenity --info --title="NexOS Toolbox" --text="No optional toolbox apps are installed in this edition yet." || true
  exit 0
fi
choice="$(zenity --list --title="NexOS Toolbox" --width=780 --height=520 --column="Category" --column="App" --column="Purpose" "${menu_items[@]}" || true)"
[[ -n "$choice" ]] || exit 0
# zenity returns first column by default, so use a launcher selection helper if duplicate category is chosen.
app="$(zenity --entry --title="Open Tool" --text="Type the app name exactly as shown, or cancel.\nSelected category: $choice" || true)"
[[ -n "$app" ]] || exit 0
case "$app" in
  Blender) blender >/dev/null 2>&1 & ;;
  FreeCAD) freecad >/dev/null 2>&1 & ;;
  OpenSCAD) openscad >/dev/null 2>&1 & ;;
  GIMP) gimp >/dev/null 2>&1 & ;;
  Inkscape) inkscape >/dev/null 2>&1 & ;;
  Krita) krita >/dev/null 2>&1 & ;;
  Audacity) audacity >/dev/null 2>&1 & ;;
  Kdenlive) kdenlive >/dev/null 2>&1 & ;;
  "OBS Studio") obs >/dev/null 2>&1 & ;;
  VLC) vlc >/dev/null 2>&1 & ;;
  Geany) geany >/dev/null 2>&1 & ;;
  Kate) kate >/dev/null 2>&1 & ;;
  "Code::Blocks") codeblocks >/dev/null 2>&1 & ;;
  "Qt Creator") qtcreator >/dev/null 2>&1 & ;;
  "SQLite Browser") sqlitebrowser >/dev/null 2>&1 & ;;
  FileZilla) filezilla >/dev/null 2>&1 & ;;
  Remmina) remmina >/dev/null 2>&1 & ;;
  "LibreOffice Writer") libreoffice --writer >/dev/null 2>&1 & ;;
  Thunderbird) thunderbird >/dev/null 2>&1 & ;;
  KeePassXC) keepassxc >/dev/null 2>&1 & ;;
  GParted) gparted >/dev/null 2>&1 & ;;
  "Disk Utility") gnome-disks >/dev/null 2>&1 & ;;
  Stellarium) stellarium >/dev/null 2>&1 & ;;
  Octave) octave --gui >/dev/null 2>&1 & ;;
  *) zenity --warning --title="NexOS Toolbox" --text="Unknown or unavailable app: $app" || true ;;
esac
TOOLBOX
chmod 0755 /usr/local/bin/nexos-toolbox
# Backward-compatible alias from earlier creator build.
ln -sf /usr/local/bin/nexos-toolbox /usr/local/bin/nexos-studio

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
  tools) EXTRA="Tools edition integrates many open-source apps into NexOS Toolbox. Try: nexos-toolbox" ;;
  creator) EXTRA="Creator build is available, but the broader direction is NexOS Tools. Try: nexos-toolbox" ;;
  security) EXTRA="Security edition tools are included. Try: nexos-security-center" ;;
  *) EXTRA="This is the clean main NexOS edition. Extra tool packs are separate builds." ;;
esac
zenity --info --title="Welcome to NexOS" --width=680 --height=410 --text="<b>Welcome to $EDITION</b>\n\nThis is your own NexOS operating system. Open-source apps are configured, launched, and organized as NexOS tools.\n\nLogin: nexos / nexos\n\n$EXTRA\n\nTry:\n  nexos-info\n  nexos-system-report\n  nexos-toolbox" || true
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

cat > "/home/$LIVE_USERNAME/Desktop/NexOS Toolbox.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Toolbox
Exec=nexos-toolbox
Icon=applications-accessories
Terminal=false
Categories=Utility;
DESKTOP
chmod 0755 "/home/$LIVE_USERNAME/Desktop/NexOS Toolbox.desktop"

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

cat > /usr/share/applications/nexos-toolbox.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Toolbox
Exec=nexos-toolbox
Icon=applications-accessories
Terminal=false
Categories=Utility;
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
