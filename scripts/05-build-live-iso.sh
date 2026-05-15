#!/usr/bin/env bash
# Builds a bootable NexOS live ISO using Debian live-build.
# Editions:
#   main     = normal NexOS desktop without extra security stack
#   security = NexOS desktop plus security-center tools

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
  main|security) ;;
  *) fail "Invalid NEXOS_EDITION='$NEXOS_EDITION'. Use: main or security" ;;
esac

BASE_ISO_NAME="${ISO_IMAGE_NAME%.iso}"
if [[ "$NEXOS_EDITION" == "main" ]]; then
  OUTPUT_ISO="$ARTIFACT_ISO"
  EDITION_LABEL="NexOS Main"
else
  OUTPUT_ISO="$ISO_DIR/${BASE_ISO_NAME}-security.iso"
  EDITION_LABEL="NexOS Security"
fi

ensure_dir "$ISO_DIR"
ensure_dir "$LOG_DIR"

log "Building edition: $NEXOS_EDITION"
log "Preparing fresh live-build configuration."
if [[ -d "$LIVE_BUILD_DIR/config" ]]; then
  (cd "$LIVE_BUILD_DIR" && lb clean --purge >/dev/null 2>&1 || true)
fi
bash "$BUILD_SCRIPT_DIR/02-init-live-build.sh"

log "Injecting $EDITION_LABEL desktop polish and forced live login."

cat > "$LB_CONFIG_DIR/package-lists/40-nexos-main-desktop-tools.list.chroot" <<'PKGS'
# NexOS main desktop/open-source tools. No extra security stack here.
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
# NexOS Security edition tools.
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

cat > "$LB_CONFIG_DIR/hooks/normal/020-nexos-edition-desktop.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

LIVE_USERNAME="__LIVE_USERNAME__"
LIVE_FULLNAME="__LIVE_FULLNAME__"
LIVE_PASSWORD="__LIVE_USERNAME__"
NEXOS_EDITION="__NEXOS_EDITION__"
EDITION_LABEL="__EDITION_LABEL__"

# Optional packages are guarded so one renamed/missing package will not break the ISO.
main_optional_packages=(
  xfce4-whiskermenu-plugin xfce4-power-manager xfce4-goodies rofi baobab
  fastfetch neofetch pciutils usbutils lshw inxi geany-plugins gparted simple-scan
)
security_optional_packages=(openscap-scanner scap-security-guide)

apt-get update || true
for pkg in "${main_optional_packages[@]}"; do
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    apt-get install -y --no-install-recommends "$pkg" || true
  fi
done

if [[ "$NEXOS_EDITION" == "security" ]]; then
  for pkg in "${security_optional_packages[@]}"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
      apt-get install -y --no-install-recommends "$pkg" || true
    fi
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

cat > /usr/local/bin/nexos-welcome <<'WELCOME'
#!/usr/bin/env bash
set -euo pipefail
EDITION="__EDITION_LABEL__"
if [[ "__NEXOS_EDITION__" == "security" ]]; then
  EXTRA="Security edition tools are included. Try: nexos-security-center"
else
  EXTRA="This is the clean main edition without the extra security stack."
fi
zenity --info --title="Welcome to NexOS" --width=620 --height=390 --text="<b>Welcome to $EDITION</b>\n\nLogin: nexos / nexos\n\n$EXTRA\n\nTry:\n  nexos-info\n  nexos-system-report" || true
WELCOME
chmod 0755 /usr/local/bin/nexos-welcome

if [[ "$NEXOS_EDITION" == "security" ]]; then
  echo Basic > /etc/nexos-security-profile
  cat > /usr/local/bin/nexos-security-center <<'SECURITY'
#!/usr/bin/env bash
set -euo pipefail
pause(){ read -rp "Press Enter to continue..." _; }
header(){ clear || true; echo "NexOS Security Center"; echo "====================="; echo; }
status(){ header; echo "Profile: $(cat /etc/nexos-security-profile 2>/dev/null || echo Basic)"; echo; echo "Firewall:"; command -v ufw >/dev/null && sudo ufw status || echo "UFW not installed"; echo; echo "AppArmor:"; command -v aa-status >/dev/null && sudo aa-status || echo "AppArmor tools not installed"; echo; pause; }
basic(){ echo Basic | sudo tee /etc/nexos-security-profile >/dev/null; command -v ufw >/dev/null && sudo ufw --force enable >/dev/null 2>&1 || true; echo "Basic profile applied."; }
enhanced(){ echo Enhanced | sudo tee /etc/nexos-security-profile >/dev/null; command -v ufw >/dev/null && sudo ufw default deny incoming >/dev/null 2>&1 || true; command -v ufw >/dev/null && sudo ufw default allow outgoing >/dev/null 2>&1 || true; command -v ufw >/dev/null && sudo ufw --force enable >/dev/null 2>&1 || true; command -v aa-enforce >/dev/null && sudo aa-enforce /etc/apparmor.d/* >/dev/null 2>&1 || true; echo "Enhanced profile applied."; }
maximum(){ echo Maximum | sudo tee /etc/nexos-security-profile >/dev/null; enhanced >/dev/null 2>&1 || true; command -v freshclam >/dev/null && sudo freshclam || true; echo "Maximum profile staged. Full hardening is for the installed build."; }
report(){ header; command -v lynis >/dev/null && sudo lynis audit system --quick || echo "Lynis not installed."; pause; }
while true; do
  header
  echo "1) Show security status"
  echo "2) Apply Basic profile"
  echo "3) Apply Enhanced profile"
  echo "4) Apply Maximum profile"
  echo "5) Run quick security report"
  echo "6) Exit"
  echo
  read -rp "Choose: " c
  case "$c" in
    1) status;; 2) basic; pause;; 3) enhanced; pause;; 4) maximum; pause;; 5) report;; 6) exit 0;; *) echo "Invalid"; sleep 1;;
  esac
done
SECURITY
  chmod 0755 /usr/local/bin/nexos-security-center
fi

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
  cat > /usr/share/applications/nexos-security-center.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Security Center
Exec=xfce4-terminal --command=nexos-security-center
Icon=security-high
Terminal=false
Categories=System;Security;
DESKTOP
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
  "$LB_CONFIG_DIR/hooks/normal/020-nexos-edition-desktop.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/020-nexos-edition-desktop.hook.chroot"

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
