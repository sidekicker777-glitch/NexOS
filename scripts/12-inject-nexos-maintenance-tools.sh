#!/usr/bin/env bash
# Injects NexOS maintenance/admin helpers for Main and Security editions.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

NEXOS_EDITION="${NEXOS_EDITION:-main}"
EDITION_LABEL="${EDITION_LABEL:-NexOS Main}"

ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"

cat > "$LB_CONFIG_DIR/package-lists/46-nexos-maintenance-tools.list.chroot" <<'PKGS'
# NexOS maintenance helper dependencies.
rsync
pciutils
usbutils
iproute2
iputils-ping
dnsutils
traceroute
PKGS

cat > "$LB_CONFIG_DIR/hooks/normal/060-nexos-maintenance-tools.hook.chroot" <<'HOOK'
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
for pkg in rsync pciutils usbutils iproute2 iputils-ping dnsutils traceroute; do
  install_if_available "$pkg"
done

mkdir -p /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/Desktop" "$home_dir/Documents/NexOS" "$home_dir/Backups"

cat > /usr/local/bin/nexos-network-helper <<'NETWORK'
#!/usr/bin/env bash
set -euo pipefail

run_report() {
  report="/tmp/nexos-network-report-$(date +%s).txt"
  {
    echo "NexOS Network Report"
    echo "===================="
    date
    echo
    echo "Interfaces:"
    ip -br addr || true
    echo
    echo "Routes:"
    ip route || true
    echo
    echo "DNS:"
    cat /etc/resolv.conf || true
    echo
    echo "Ping test:"
    ping -c 3 1.1.1.1 || true
  } > "$report" 2>&1
  if command -v mousepad >/dev/null 2>&1; then mousepad "$report" >/dev/null 2>&1 & else xdg-open "$report" >/dev/null 2>&1 & fi
}

choice="$(zenity --list --title="NexOS Network Helper" --width=720 --height=430 --print-column=1 --column="Action" --column="Description" \
  "Open Network Settings" "Edit wired/Wi-Fi connections" \
  "Show Network Report" "Create a simple network report" \
  "Ping Cloudflare DNS" "Test internet connectivity" \
  "Show IP Addresses" "Show active interface addresses" || true)"
[[ -n "$choice" ]] || exit 0
case "$choice" in
  "Open Network Settings") nm-connection-editor >/dev/null 2>&1 & ;;
  "Show Network Report") run_report ;;
  "Ping Cloudflare DNS") xfce4-terminal --title="NexOS Ping Test" --command="bash -lc 'ping -c 5 1.1.1.1; echo; read -p \"Press Enter...\"'" >/dev/null 2>&1 & ;;
  "Show IP Addresses") xfce4-terminal --title="NexOS IP Addresses" --command="bash -lc 'ip -br addr; echo; read -p \"Press Enter...\"'" >/dev/null 2>&1 & ;;
esac
NETWORK
chmod 0755 /usr/local/bin/nexos-network-helper

cat > /usr/local/bin/nexos-backup-helper <<'BACKUP'
#!/usr/bin/env bash
set -euo pipefail

src="$(zenity --file-selection --directory --title="NexOS Backup Helper - Choose folder to backup" --filename="$HOME/" || true)"
[[ -n "$src" ]] || exit 0
out_parent="$(zenity --file-selection --directory --title="NexOS Backup Helper - Choose backup destination" --filename="$HOME/Backups/" || true)"
[[ -n "$out_parent" ]] || exit 0
mkdir -p "$out_parent"
base="$(basename "$src")"
stamp="$(date +%Y%m%d-%H%M%S)"
out="$out_parent/${base}-backup-$stamp.tar.gz"
log="/tmp/nexos-backup-$stamp.log"
{
  echo "NexOS Backup Helper"
  echo "Source: $src"
  echo "Output: $out"
  echo
  tar -czf "$out" -C "$(dirname "$src")" "$base"
  echo
  ls -lh "$out"
} > "$log" 2>&1 && {
  zenity --question --title="NexOS Backup Helper" --text="Backup complete.\n\n$out\n\nOpen the backup folder?" && xdg-open "$out_parent" >/dev/null 2>&1 &
} || {
  zenity --text-info --title="NexOS Backup Error" --width=760 --height=480 --filename="$log" || true
  exit 1
}
BACKUP
chmod 0755 /usr/local/bin/nexos-backup-helper

cat > /usr/local/bin/nexos-hardware-info <<'HARDWARE'
#!/usr/bin/env bash
set -euo pipefail
report="/tmp/nexos-hardware-report-$(date +%s).txt"
{
  echo "NexOS Hardware Report"
  echo "====================="
  date
  echo
  echo "Kernel:"
  uname -a
  echo
  echo "CPU/Memory:"
  lscpu 2>/dev/null || true
  echo
  free -h 2>/dev/null || true
  echo
  echo "PCI devices:"
  lspci 2>/dev/null || true
  echo
  echo "USB devices:"
  lsusb 2>/dev/null || true
  echo
  echo "Block devices:"
  lsblk 2>/dev/null || true
} > "$report" 2>&1
if command -v mousepad >/dev/null 2>&1; then mousepad "$report" >/dev/null 2>&1 & else xdg-open "$report" >/dev/null 2>&1 & fi
HARDWARE
chmod 0755 /usr/local/bin/nexos-hardware-info

cat > /usr/local/bin/nexos-maintenance-center <<'MAINT'
#!/usr/bin/env bash
set -euo pipefail
entries=(
  "Network|NexOS Network Helper|nexos-network-helper|Network tests and settings"
  "Backup|NexOS Backup Helper|nexos-backup-helper|Create a tar.gz backup of a folder"
  "Hardware|NexOS Hardware Info|nexos-hardware-info|Create a hardware report"
  "Repair|NexOS Repair Tools|nexos-repair-tools|Desktop/session repair actions"
  "Updates|NexOS Update Helper|nexos-update-helper|Check live package updates"
  "System|NexOS System Report|nexos-system-report|Show system report"
)
items=()
for row in "${entries[@]}"; do
  IFS='|' read -r cat name cmd desc <<< "$row"
  command -v "$cmd" >/dev/null 2>&1 && items+=("$cat" "$name" "$desc")
done
choice="$(zenity --list --title="NexOS Maintenance Center" --width=780 --height=500 --print-column=2 --column="Category" --column="Tool" --column="Description" "${items[@]}" || true)"
[[ -n "$choice" ]] || exit 0
case "$choice" in
  "NexOS Network Helper") nexos-network-helper >/dev/null 2>&1 & ;;
  "NexOS Backup Helper") nexos-backup-helper >/dev/null 2>&1 & ;;
  "NexOS Hardware Info") nexos-hardware-info >/dev/null 2>&1 & ;;
  "NexOS Repair Tools") nexos-repair-tools >/dev/null 2>&1 & ;;
  "NexOS Update Helper") nexos-update-helper >/dev/null 2>&1 & ;;
  "NexOS System Report") xfce4-terminal --command=nexos-system-report >/dev/null 2>&1 & ;;
esac
MAINT
chmod 0755 /usr/local/bin/nexos-maintenance-center

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

make_desktop /usr/share/applications/nexos-maintenance-center.desktop "NexOS Maintenance Center" "Open NexOS maintenance and admin helpers" "nexos-maintenance-center" "applications-system" "System;Utility;"
make_desktop /usr/share/applications/nexos-network-helper.desktop "NexOS Network Helper" "Network tests and settings" "nexos-network-helper" "network-workgroup" "Network;System;"
make_desktop /usr/share/applications/nexos-backup-helper.desktop "NexOS Backup Helper" "Create a folder backup" "nexos-backup-helper" "document-save" "Utility;Archiving;"
make_desktop /usr/share/applications/nexos-hardware-info.desktop "NexOS Hardware Info" "Show hardware information" "nexos-hardware-info" "computer" "System;"

for desktop in "NexOS Maintenance Center" "NexOS Network Helper" "NexOS Backup Helper" "NexOS Hardware Info"; do
  case "$desktop" in
    "NexOS Maintenance Center") src=/usr/share/applications/nexos-maintenance-center.desktop ;;
    "NexOS Network Helper") src=/usr/share/applications/nexos-network-helper.desktop ;;
    "NexOS Backup Helper") src=/usr/share/applications/nexos-backup-helper.desktop ;;
    "NexOS Hardware Info") src=/usr/share/applications/nexos-hardware-info.desktop ;;
  esac
  cp -f "$src" "$home_dir/Desktop/$desktop.desktop" || true
  chmod 0755 "$home_dir/Desktop/$desktop.desktop" || true
done

# Add maintenance center to the app map.
cat >> /usr/share/nexos/app-map.txt <<'APPMAP_APPEND'

Maintenance helpers:
- NexOS Maintenance Center: groups repair, network, backup, update, and hardware helpers.
- NexOS Network Helper: wraps iproute2, ping, DNS, and NetworkManager tools.
- NexOS Backup Helper: creates simple tar.gz folder backups.
- NexOS Hardware Info: wraps lscpu, lspci, lsusb, lsblk, and memory info.
APPMAP_APPEND

chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel
rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK

sed -i \
  -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" \
  -e "s/__NEXOS_EDITION__/$NEXOS_EDITION/g" \
  -e "s/__EDITION_LABEL__/$EDITION_LABEL/g" \
  "$LB_CONFIG_DIR/hooks/normal/060-nexos-maintenance-tools.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/060-nexos-maintenance-tools.hook.chroot"

success "Injected NexOS maintenance tools for $NEXOS_EDITION."
