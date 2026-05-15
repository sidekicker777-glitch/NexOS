#!/usr/bin/env bash
# Injects NexOS-owned core wrapper apps into live-build config.
# Used by Main and Security first; Tools also receives them when built.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

NEXOS_EDITION="${NEXOS_EDITION:-main}"
EDITION_LABEL="${EDITION_LABEL:-NexOS Main}"

ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"

cat > "$LB_CONFIG_DIR/package-lists/45-nexos-core-wrapper-tools.list.chroot" <<'PKGS'
# NexOS core wrappers depend on these open-source tools.
zenity
xarchiver
p7zip-full
unzip
zip
libarchive-tools
thunar-archive-plugin
PKGS

cat > "$LB_CONFIG_DIR/hooks/normal/030-nexos-core-apps.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

LIVE_USERNAME="__LIVE_USERNAME__"
NEXOS_EDITION="__NEXOS_EDITION__"
EDITION_LABEL="__EDITION_LABEL__"

install_if_available() {
  local pkg="$1"
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    apt-get install -y --no-install-recommends "$pkg" || true
  fi
}

apt-get update || true
for pkg in xarchiver p7zip-full p7zip-rar unzip zip libarchive-tools thunar-archive-plugin; do
  install_if_available "$pkg"
done

mkdir -p /usr/share/nexos /usr/local/bin /usr/share/applications
mkdir -p "/home/$LIVE_USERNAME/Desktop" "/home/$LIVE_USERNAME/.config/autostart" || true

cat > /usr/share/nexos/app-map.txt <<'APPMAP'
NexOS App Map
=============

NexOS is its own operating system experience built on legal open-source foundations.

Core NexOS wrappers:
- NexOS Welcome: original NexOS welcome flow.
- NexOS Control Center: launcher for system settings and NexOS tools.
- NexOS Code Editor: wrapper around installed open-source editors.
- NexOS Extractor: simple archive extraction wrapper around open-source archive tools.
- NexOS System Report: wrapper around system information tools.

Open-source foundations currently integrated:
- Debian live-build: ISO/live system builder.
- XFCE / LightDM / Thunar: lightweight desktop foundation.
- Firefox ESR: browser foundation.
- Geany / Kate / Mousepad / Micro / Neovim: editor foundations where installed.
- 7zip / libarchive / unzip / tar: archive foundations.
- Papirus / Arc: visual theme foundations.

Rules:
- Keep NexOS branding original.
- Keep upstream project names and licenses respected.
- Configure and wrap open-source apps for NexOS instead of copying closed-source products.
- Build original NexOS apps when no good open-source base fits.
APPMAP

cat > /usr/local/bin/nexos-app-map <<'APPMAPCMD'
#!/usr/bin/env bash
set -euo pipefail
if command -v mousepad >/dev/null 2>&1; then
  mousepad /usr/share/nexos/app-map.txt >/dev/null 2>&1 &
elif command -v xdg-open >/dev/null 2>&1; then
  xdg-open /usr/share/nexos/app-map.txt >/dev/null 2>&1 &
else
  less /usr/share/nexos/app-map.txt
fi
APPMAPCMD
chmod 0755 /usr/local/bin/nexos-app-map

cat > /usr/local/bin/nexos-extractor <<'EXTRACTOR'
#!/usr/bin/env bash
set -euo pipefail

pick_file() {
  zenity --file-selection --title="NexOS Extractor - Choose archive" \
    --file-filter="Archives | *.zip *.7z *.tar *.tar.gz *.tgz *.tar.bz2 *.tbz2 *.tar.xz *.txz *.rar *.gz *.bz2 *.xz" || true
}

pick_folder() {
  zenity --file-selection --directory --title="NexOS Extractor - Choose output folder" || true
}

archive="${1:-}"
if [[ -z "$archive" ]]; then
  archive="$(pick_file)"
fi
[[ -n "$archive" ]] || exit 0
[[ -f "$archive" ]] || { zenity --error --title="NexOS Extractor" --text="Archive not found:\n$archive" || true; exit 1; }

outdir="${2:-}"
if [[ -z "$outdir" ]]; then
  outdir="$(pick_folder)"
fi
[[ -n "$outdir" ]] || exit 0
mkdir -p "$outdir"

logfile="/tmp/nexos-extractor-$(date +%s).log"
{
  echo "NexOS Extractor"
  echo "Archive: $archive"
  echo "Output:  $outdir"
  echo

  lower="${archive,,}"
  case "$lower" in
    *.zip)
      if command -v unzip >/dev/null 2>&1; then unzip -o "$archive" -d "$outdir"; else bsdtar -xf "$archive" -C "$outdir"; fi
      ;;
    *.7z)
      if command -v 7z >/dev/null 2>&1; then 7z x -y "-o$outdir" "$archive"; elif command -v 7za >/dev/null 2>&1; then 7za x -y "-o$outdir" "$archive"; else bsdtar -xf "$archive" -C "$outdir"; fi
      ;;
    *.tar|*.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz)
      tar -xf "$archive" -C "$outdir"
      ;;
    *)
      if command -v bsdtar >/dev/null 2>&1; then bsdtar -xf "$archive" -C "$outdir"; elif command -v 7z >/dev/null 2>&1; then 7z x -y "-o$outdir" "$archive"; else echo "No supported extractor found."; exit 2; fi
      ;;
  esac
} >"$logfile" 2>&1 && {
  zenity --info --title="NexOS Extractor" --text="Extraction complete.\n\nOutput folder:\n$outdir" || true
} || {
  zenity --text-info --title="NexOS Extractor Error" --width=700 --height=450 --filename="$logfile" || true
  exit 1
}
EXTRACTOR
chmod 0755 /usr/local/bin/nexos-extractor

cat > /usr/local/bin/nexos-control-center <<'CONTROL'
#!/usr/bin/env bash
set -euo pipefail

entries=(
  "System|Settings Manager|xfce4-settings-manager|Open XFCE settings"
  "System|Display Settings|xfce4-display-settings|Change resolution and monitors"
  "System|Appearance|xfce4-appearance-settings|Theme, icons, fonts"
  "System|Task Manager|xfce4-taskmanager|View running processes"
  "System|Power Settings|xfce4-power-manager-settings|Power and screen settings"
  "Network|Network Connections|nm-connection-editor|Configure network connections"
  "Printers|Printer Settings|system-config-printer|Configure printers"
  "Disks|Disk Utility|gnome-disks|Manage disks when available"
  "Disks|GParted|gparted|Partition editor when available"
  "NexOS|NexOS Code Editor|nexos-code-editor|Open NexOS editor launcher"
  "NexOS|NexOS Extractor|nexos-extractor|Extract archives"
  "NexOS|NexOS Toolbox|nexos-toolbox|Open optional tool launcher"
  "NexOS|NexOS App Map|nexos-app-map|View open-source foundations"
  "NexOS|NexOS System Report|nexos-system-report|View system report"
)

menu_items=()
for row in "${entries[@]}"; do
  IFS='|' read -r category name cmd desc <<< "$row"
  command -v "$cmd" >/dev/null 2>&1 && menu_items+=("$category" "$name" "$desc")
done

choice="$(zenity --list --title="NexOS Control Center" --width=760 --height=520 --column="Category" --column="Tool" --column="Description" "${menu_items[@]}" || true)"
[[ -n "$choice" ]] || exit 0
name="$(zenity --entry --title="Open Control Panel" --text="Type the tool name exactly as shown, or cancel.\nSelected category: $choice" || true)"
[[ -n "$name" ]] || exit 0

case "$name" in
  "Settings Manager") xfce4-settings-manager >/dev/null 2>&1 & ;;
  "Display Settings") xfce4-display-settings >/dev/null 2>&1 & ;;
  Appearance) xfce4-appearance-settings >/dev/null 2>&1 & ;;
  "Task Manager") xfce4-taskmanager >/dev/null 2>&1 & ;;
  "Power Settings") xfce4-power-manager-settings >/dev/null 2>&1 & ;;
  "Network Connections") nm-connection-editor >/dev/null 2>&1 & ;;
  "Printer Settings") system-config-printer >/dev/null 2>&1 & ;;
  "Disk Utility") gnome-disks >/dev/null 2>&1 & ;;
  GParted) gparted >/dev/null 2>&1 & ;;
  "NexOS Code Editor") nexos-code-editor >/dev/null 2>&1 & ;;
  "NexOS Extractor") nexos-extractor >/dev/null 2>&1 & ;;
  "NexOS Toolbox") nexos-toolbox >/dev/null 2>&1 & ;;
  "NexOS App Map") nexos-app-map >/dev/null 2>&1 & ;;
  "NexOS System Report") xfce4-terminal --command=nexos-system-report >/dev/null 2>&1 & ;;
  *) zenity --warning --title="NexOS Control Center" --text="Unknown or unavailable tool: $name" || true ;;
esac
CONTROL
chmod 0755 /usr/local/bin/nexos-control-center

# Desktop/menu launchers.
cat > /usr/share/applications/nexos-control-center.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Control Center
Comment=Open NexOS settings and tools
Exec=nexos-control-center
Icon=preferences-system
Terminal=false
Categories=Settings;System;
DESKTOP

cat > /usr/share/applications/nexos-extractor.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Extractor
Comment=Extract archives with NexOS
Exec=nexos-extractor
Icon=package-x-generic
Terminal=false
Categories=Utility;Archiving;
DESKTOP

cat > /usr/share/applications/nexos-app-map.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS App Map
Comment=Show NexOS open-source foundations
Exec=nexos-app-map
Icon=text-x-generic
Terminal=false
Categories=Documentation;System;
DESKTOP

for desktop in "NexOS Control Center" "NexOS Extractor" "NexOS App Map"; do
  case "$desktop" in
    "NexOS Control Center") src=/usr/share/applications/nexos-control-center.desktop ;;
    "NexOS Extractor") src=/usr/share/applications/nexos-extractor.desktop ;;
    "NexOS App Map") src=/usr/share/applications/nexos-app-map.desktop ;;
  esac
  if [[ -d "/home/$LIVE_USERNAME/Desktop" ]]; then
    cp -f "$src" "/home/$LIVE_USERNAME/Desktop/$desktop.desktop" || true
    chmod 0755 "/home/$LIVE_USERNAME/Desktop/$desktop.desktop" || true
  fi
done

chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "/home/$LIVE_USERNAME" 2>/dev/null || true
mkdir -p /etc/skel
rsync -a "/home/$LIVE_USERNAME/" /etc/skel/ 2>/dev/null || true
HOOK

sed -i \
  -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" \
  -e "s/__NEXOS_EDITION__/$NEXOS_EDITION/g" \
  -e "s/__EDITION_LABEL__/$EDITION_LABEL/g" \
  "$LB_CONFIG_DIR/hooks/normal/030-nexos-core-apps.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/030-nexos-core-apps.hook.chroot"

success "Injected NexOS core wrapper apps for $NEXOS_EDITION."
