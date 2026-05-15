#!/usr/bin/env bash
# Injects NexOS Install Center into the live ISO.
# Goal: move NexOS closer to a real installable OS while keeping warnings clear.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

NEXOS_EDITION="${NEXOS_EDITION:-main}"
EDITION_LABEL="${EDITION_LABEL:-NexOS Main}"

ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"

cat > "$LB_CONFIG_DIR/package-lists/48-nexos-install-center-tools.list.chroot" <<'PKGS'
# NexOS Install Center dependencies.
# Calamares is the preferred open-source installer foundation when available.
calamares
calamares-settings-debian
gparted
parted
dosfstools
e2fsprogs
ntfs-3g
PKGS

cat > "$LB_CONFIG_DIR/hooks/normal/080-nexos-install-center.hook.chroot" <<'HOOK'
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
for pkg in calamares calamares-settings-debian gparted parted dosfstools e2fsprogs ntfs-3g; do
  install_if_available "$pkg"
done

mkdir -p /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/Desktop" "$home_dir/Documents/NexOS"

cat > /usr/local/bin/nexos-disk-check <<'DISKCHECK'
#!/usr/bin/env bash
set -euo pipefail
report="/tmp/nexos-disk-check-$(date +%s).txt"
{
  echo "NexOS Disk Check"
  echo "================"
  date
  echo
  echo "This report helps you identify disks before installing NexOS."
  echo "Be careful: installing an OS can erase data if the wrong disk is chosen."
  echo
  echo "Block devices:"
  lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL 2>/dev/null || lsblk || true
  echo
  echo "Partitions:"
  sudo parted -l 2>/dev/null || true
} > "$report" 2>&1
if command -v mousepad >/dev/null 2>&1; then mousepad "$report" >/dev/null 2>&1 & else xdg-open "$report" >/dev/null 2>&1 & fi
DISKCHECK
chmod 0755 /usr/local/bin/nexos-disk-check

cat > /usr/local/bin/nexos-installer <<'INSTALLER'
#!/usr/bin/env bash
set -euo pipefail

msg="NexOS Installer\n\nThis is the first install-center integration.\n\nUse this only in your VirtualBox test VM unless you fully understand disk partitioning. Installing an OS can erase disks.\n\nRecommended VM test setup:\n• 2 CPU cores\n• 4096 MB RAM or more\n• 30+ GB virtual disk\n• Boot from the NexOS ISO\n\nContinue?"
zenity --question --title="NexOS Installer" --width=620 --height=360 --text="$msg" || exit 0

if command -v calamares >/dev/null 2>&1; then
  pkexec calamares >/dev/null 2>&1 || sudo calamares || calamares
else
  zenity --warning --title="NexOS Installer" --width=620 --text="Calamares is not installed or not available in this build yet.\n\nUse NexOS Disk Check and GParted for preparation. The next build step should add a full custom installer config." || true
fi
INSTALLER
chmod 0755 /usr/local/bin/nexos-installer

cat > /usr/local/bin/nexos-install-center <<'CENTER'
#!/usr/bin/env bash
set -euo pipefail
entries=(
  "Install NexOS|nexos-installer|Launch the installer foundation when available"
  "Disk Check|nexos-disk-check|Show disks and partitions before installing"
  "Partition Editor|gparted|Open GParted when available"
  "Hardware Info|nexos-hardware-info|Show hardware report"
  "System Report|nexos-system-report|Show NexOS system report"
  "Help|nexos-help|Open NexOS help"
)
items=()
for row in "${entries[@]}"; do
  IFS='|' read -r name cmd desc <<< "$row"
  command -v "$cmd" >/dev/null 2>&1 && items+=("$name" "$desc")
done
choice="$(zenity --list --title="NexOS Install Center" --width=760 --height=460 --print-column=1 --column="Tool" --column="Description" "${items[@]}" || true)"
[[ -n "$choice" ]] || exit 0
case "$choice" in
  "Install NexOS") nexos-installer >/dev/null 2>&1 & ;;
  "Disk Check") nexos-disk-check >/dev/null 2>&1 & ;;
  "Partition Editor") gparted >/dev/null 2>&1 & ;;
  "Hardware Info") nexos-hardware-info >/dev/null 2>&1 & ;;
  "System Report") xfce4-terminal --command=nexos-system-report >/dev/null 2>&1 & ;;
  Help) nexos-help >/dev/null 2>&1 & ;;
esac
CENTER
chmod 0755 /usr/local/bin/nexos-install-center

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

make_desktop /usr/share/applications/nexos-install-center.desktop "NexOS Install Center" "Install and prepare NexOS" "nexos-install-center" "system-software-install" "System;Settings;"
make_desktop /usr/share/applications/nexos-installer.desktop "Install NexOS" "Launch the NexOS installer" "nexos-installer" "system-software-install" "System;Settings;"
make_desktop /usr/share/applications/nexos-disk-check.desktop "NexOS Disk Check" "Show disk and partition information" "nexos-disk-check" "drive-harddisk" "System;"

cp -f /usr/share/applications/nexos-install-center.desktop "$home_dir/Desktop/NexOS Install Center.desktop" || true
cp -f /usr/share/applications/nexos-disk-check.desktop "$home_dir/Desktop/NexOS Disk Check.desktop" || true
chmod 0755 "$home_dir/Desktop/NexOS Install Center.desktop" "$home_dir/Desktop/NexOS Disk Check.desktop" 2>/dev/null || true

cat >> /usr/share/nexos/app-map.txt <<'APPMAP_APPEND'

Installer foundation:
- NexOS Install Center: installer launcher and VM install preparation flow.
- NexOS Installer: wraps Calamares when the open-source installer is available.
- NexOS Disk Check: wraps lsblk and parted to help identify disks before installing.
APPMAP_APPEND

chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel
rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK

sed -i \
  -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" \
  -e "s/__NEXOS_EDITION__/$NEXOS_EDITION/g" \
  -e "s/__EDITION_LABEL__/$EDITION_LABEL/g" \
  "$LB_CONFIG_DIR/hooks/normal/080-nexos-install-center.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/080-nexos-install-center.hook.chroot"

success "Injected NexOS Install Center for $NEXOS_EDITION."
