#!/usr/bin/env bash
# Injects NexOS-owned core wrapper apps into live-build config.
# Main and Security are the focus. Tools also receives these when built.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

NEXOS_EDITION="${NEXOS_EDITION:-main}"
EDITION_LABEL="${EDITION_LABEL:-NexOS Main}"

ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"

cat > "$LB_CONFIG_DIR/package-lists/45-nexos-core-wrapper-tools.list.chroot" <<'PKGS'
# NexOS core wrapper dependencies.
zenity
xarchiver
7zip
unzip
zip
libarchive-tools
thunar-archive-plugin
xdg-utils
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
for pkg in xarchiver 7zip unzip zip libarchive-tools thunar-archive-plugin xdg-utils; do
  install_if_available "$pkg"
done

mkdir -p /usr/share/nexos /usr/local/bin /usr/share/applications
mkdir -p "/home/$LIVE_USERNAME/Desktop" "/home/$LIVE_USERNAME/.config/autostart" "/home/$LIVE_USERNAME/.config/Thunar" "/home/$LIVE_USERNAME/.config/nexos" || true

cat > /usr/share/nexos/app-map.txt <<'APPMAP'
NexOS App Map
=============

NexOS is its own operating system experience built on legal open-source foundations.
Open-source apps are configured, wrapped, and organized by NexOS instead of being treated as the OS identity.

Core NexOS wrappers:
- NexOS Welcome: original NexOS welcome flow.
- NexOS First Setup: first-boot setup checklist.
- NexOS Control Center: launcher for system settings and NexOS tools.
- NexOS Code Editor: wrapper around installed open-source editors.
- NexOS Extractor: simple archive extraction wrapper around open-source archive tools.
- NexOS Repair Tools: quick desktop repair and troubleshooting actions.
- NexOS Update Helper: live-system update/help screen.
- NexOS Browser: browser launcher around Firefox ESR when installed.
- NexOS System Report: wrapper around system information tools.

Open-source foundations currently integrated:
- Debian live-build: ISO/live system builder.
- XFCE / LightDM / Thunar: lightweight desktop foundation.
- Firefox ESR: browser foundation.
- Geany / Kate / Mousepad / Micro / Neovim: editor foundations where installed.
- 7zip / libarchive / unzip / tar: archive foundations.
- Papirus / Arc: visual theme foundations.

Edition focus:
- Main: clean daily-use NexOS.
- Security: Main plus security/admin tools.
- Tools: optional broad tool pack, not the main focus.

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

cat > /usr/local/bin/nexos-browser <<'BROWSER'
#!/usr/bin/env bash
set -euo pipefail
url="${1:-}"
if command -v firefox-esr >/dev/null 2>&1; then
  firefox-esr ${url:+"$url"} >/dev/null 2>&1 &
elif command -v firefox >/dev/null 2>&1; then
  firefox ${url:+"$url"} >/dev/null 2>&1 &
else
  zenity --warning --title="NexOS Browser" --text="No browser is installed yet." || true
fi
BROWSER
chmod 0755 /usr/local/bin/nexos-browser

cat > /usr/local/bin/nexos-update-helper <<'UPDATEHELPER'
#!/usr/bin/env bash
set -euo pipefail
xfce4-terminal --title="NexOS Update Helper" --command="bash -lc 'echo NexOS Update Helper; echo ====================; echo; echo This live ISO can check package updates, but changes are temporary until NexOS has an installed mode.; echo; sudo apt update; echo; apt list --upgradable 2>/dev/null || true; echo; read -p \"Press Enter to close...\"'" >/dev/null 2>&1 &
UPDATEHELPER
chmod 0755 /usr/local/bin/nexos-update-helper

cat > /usr/local/bin/nexos-extractor <<'EXTRACTOR'
#!/usr/bin/env bash
set -euo pipefail
archive="${1:-}"
if [[ -z "$archive" ]]; then
  archive="$(zenity --file-selection --title="NexOS Extractor - Choose archive" --file-filter="Archives | *.zip *.7z *.tar *.tar.gz *.tgz *.tar.bz2 *.tbz2 *.tar.xz *.txz *.rar *.gz *.bz2 *.xz" || true)"
fi
[[ -n "$archive" ]] || exit 0
[[ -f "$archive" ]] || { zenity --error --title="NexOS Extractor" --text="Archive not found:\n$archive" || true; exit 1; }
base_name="$(basename "$archive")"
default_out="$HOME/Extracted/${base_name%.*}"
outdir="${2:-}"
if [[ -z "$outdir" ]]; then
  mkdir -p "$default_out"
  outdir="$(zenity --file-selection --directory --title="NexOS Extractor - Choose output folder" --filename="$default_out/" || true)"
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
    *.zip) if command -v unzip >/dev/null 2>&1; then unzip -o "$archive" -d "$outdir"; else bsdtar -xf "$archive" -C "$outdir"; fi ;;
    *.7z) if command -v 7z >/dev/null 2>&1; then 7z x -y "-o$outdir" "$archive"; elif command -v 7za >/dev/null 2>&1; then 7za x -y "-o$outdir" "$archive"; else bsdtar -xf "$archive" -C "$outdir"; fi ;;
    *.tar|*.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz) tar -xf "$archive" -C "$outdir" ;;
    *) if command -v bsdtar >/dev/null 2>&1; then bsdtar -xf "$archive" -C "$outdir"; elif command -v 7z >/dev/null 2>&1; then 7z x -y "-o$outdir" "$archive"; else echo "No supported extractor found."; exit 2; fi ;;
  esac
} >"$logfile" 2>&1 && {
  zenity --question --title="NexOS Extractor" --text="Extraction complete.\n\nOutput folder:\n$outdir\n\nOpen the folder now?" && xdg-open "$outdir" >/dev/null 2>&1 &
} || {
  zenity --text-info --title="NexOS Extractor Error" --width=760 --height=480 --filename="$logfile" || true
  exit 1
}
EXTRACTOR
chmod 0755 /usr/local/bin/nexos-extractor

cat > /usr/local/bin/nexos-repair-tools <<'REPAIR'
#!/usr/bin/env bash
set -euo pipefail
entries=(
  "Desktop|Restart XFCE Panel|restart-panel|Fix missing/frozen taskbar"
  "Desktop|Restart File Manager|restart-thunar|Fix desktop icons/file manager"
  "Network|Open Network Settings|network-settings|Edit network connections"
  "System|Open Terminal|terminal|Open a terminal"
  "System|System Report|system-report|Show NexOS report"
  "System|Clean Temp Files|clean-temp|Clean safe temporary user files"
)
choice="$(zenity --list --title="NexOS Repair Tools" --width=720 --height=430 --print-column=2 --column="Category" --column="Action" --column="Description" "${entries[@]}" || true)"
[[ -n "$choice" ]] || exit 0
case "$choice" in
  "Restart XFCE Panel") xfce4-panel --restart >/dev/null 2>&1 & ;;
  "Restart File Manager") thunar -q >/dev/null 2>&1 || true; thunar --daemon >/dev/null 2>&1 & ;;
  "Open Network Settings") nm-connection-editor >/dev/null 2>&1 & ;;
  "Open Terminal") xfce4-terminal >/dev/null 2>&1 & ;;
  "System Report") xfce4-terminal --command=nexos-system-report >/dev/null 2>&1 & ;;
  "Clean Temp Files") rm -rf "$HOME/.cache/thumbnails"/* /tmp/nexos-* 2>/dev/null || true; zenity --info --title="NexOS Repair Tools" --text="Safe temporary files cleaned." || true ;;
  *) zenity --warning --title="NexOS Repair Tools" --text="Unknown action: $choice" || true ;;
esac
REPAIR
chmod 0755 /usr/local/bin/nexos-repair-tools

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
  "NexOS|NexOS First Setup|nexos-first-setup|Run first setup again"
  "NexOS|NexOS Browser|nexos-browser|Open the web browser"
  "NexOS|NexOS Code Editor|nexos-code-editor|Open NexOS editor launcher"
  "NexOS|NexOS Extractor|nexos-extractor|Extract archives"
  "NexOS|NexOS Repair Tools|nexos-repair-tools|Fix common desktop/session issues"
  "NexOS|NexOS Update Helper|nexos-update-helper|Check package updates"
  "NexOS|NexOS Toolbox|nexos-toolbox|Open optional tool launcher"
  "NexOS|NexOS App Map|nexos-app-map|View open-source foundations"
  "NexOS|NexOS System Report|nexos-system-report|View system report"
  "Security|NexOS Security Center|nexos-security-center|Open security tools when installed"
)
menu_items=()
for row in "${entries[@]}"; do
  IFS='|' read -r category name cmd desc <<< "$row"
  command -v "$cmd" >/dev/null 2>&1 && menu_items+=("$category" "$name" "$desc")
done
if (( ${#menu_items[@]} == 0 )); then
  zenity --warning --title="NexOS Control Center" --text="No control center tools are available." || true
  exit 1
fi
choice="$(zenity --list --title="NexOS Control Center" --width=800 --height=560 --print-column=2 --column="Category" --column="Tool" --column="Description" "${menu_items[@]}" || true)"
[[ -n "$choice" ]] || exit 0
case "$choice" in
  "Settings Manager") xfce4-settings-manager >/dev/null 2>&1 & ;;
  "Display Settings") xfce4-display-settings >/dev/null 2>&1 & ;;
  Appearance) xfce4-appearance-settings >/dev/null 2>&1 & ;;
  "Task Manager") xfce4-taskmanager >/dev/null 2>&1 & ;;
  "Power Settings") xfce4-power-manager-settings >/dev/null 2>&1 & ;;
  "Network Connections") nm-connection-editor >/dev/null 2>&1 & ;;
  "Printer Settings") system-config-printer >/dev/null 2>&1 & ;;
  "Disk Utility") gnome-disks >/dev/null 2>&1 & ;;
  GParted) gparted >/dev/null 2>&1 & ;;
  "NexOS First Setup") nexos-first-setup --force >/dev/null 2>&1 & ;;
  "NexOS Browser") nexos-browser >/dev/null 2>&1 & ;;
  "NexOS Code Editor") nexos-code-editor >/dev/null 2>&1 & ;;
  "NexOS Extractor") nexos-extractor >/dev/null 2>&1 & ;;
  "NexOS Repair Tools") nexos-repair-tools >/dev/null 2>&1 & ;;
  "NexOS Update Helper") nexos-update-helper >/dev/null 2>&1 & ;;
  "NexOS Toolbox") nexos-toolbox >/dev/null 2>&1 & ;;
  "NexOS App Map") nexos-app-map >/dev/null 2>&1 & ;;
  "NexOS System Report") xfce4-terminal --command=nexos-system-report >/dev/null 2>&1 & ;;
  "NexOS Security Center") xfce4-terminal --command=nexos-security-center >/dev/null 2>&1 & ;;
  *) zenity --warning --title="NexOS Control Center" --text="Unknown or unavailable tool: $choice" || true ;;
esac
CONTROL
chmod 0755 /usr/local/bin/nexos-control-center

cat > /usr/local/bin/nexos-first-setup <<'FIRSTSETUP'
#!/usr/bin/env bash
set -euo pipefail
done_file="$HOME/.config/nexos/first-setup.done"
mkdir -p "$(dirname "$done_file")"
if [[ "${1:-}" != "--force" && -f "$done_file" ]]; then
  exit 0
fi
while true; do
  choice="$(zenity --list --title="NexOS First Setup" --width=760 --height=500 --print-column=1 --column="Step" --column="What it does" \
    "Open Control Center" "Main settings and NexOS tools" \
    "Set Display" "Resolution and monitor settings" \
    "Set Network" "Wi-Fi/Ethernet connections" \
    "Open Code Editor" "Choose a code editor" \
    "View App Map" "See open-source foundations" \
    "Finish Setup" "Do not show this on next login" || true)"
  [[ -n "$choice" ]] || exit 0
  case "$choice" in
    "Open Control Center") nexos-control-center >/dev/null 2>&1 & ;;
    "Set Display") xfce4-display-settings >/dev/null 2>&1 & ;;
    "Set Network") nm-connection-editor >/dev/null 2>&1 & ;;
    "Open Code Editor") nexos-code-editor >/dev/null 2>&1 & ;;
    "View App Map") nexos-app-map >/dev/null 2>&1 & ;;
    "Finish Setup") date > "$done_file"; zenity --info --title="NexOS First Setup" --text="Setup complete. You can reopen this from NexOS Control Center." || true; exit 0 ;;
  esac
done
FIRSTSETUP
chmod 0755 /usr/local/bin/nexos-first-setup

# Thunar custom action: right-click archive -> Extract with NexOS.
cat > "/home/$LIVE_USERNAME/.config/Thunar/uca.xml" <<'UCA'
<?xml version="1.0" encoding="UTF-8"?>
<actions>
<action>
  <icon>package-x-generic</icon>
  <name>Extract with NexOS</name>
  <submenu></submenu>
  <unique-id>1700000001-1</unique-id>
  <command>nexos-extractor %f</command>
  <description>Extract selected archive with NexOS Extractor</description>
  <patterns>*.zip;*.7z;*.tar;*.tar.gz;*.tgz;*.tar.bz2;*.tbz2;*.tar.xz;*.txz;*.rar;*.gz;*.bz2;*.xz</patterns>
  <directories/>
  <audio-files/>
  <image-files/>
  <other-files/>
  <text-files/>
  <video-files/>
</action>
</actions>
UCA

# Desktop/menu launchers.
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

make_desktop /usr/share/applications/nexos-control-center.desktop "NexOS Control Center" "Open NexOS settings and tools" "nexos-control-center" "preferences-system" "Settings;System;"
make_desktop /usr/share/applications/nexos-first-setup.desktop "NexOS First Setup" "Run the NexOS first setup checklist" "nexos-first-setup --force" "preferences-system" "Settings;System;"
make_desktop /usr/share/applications/nexos-browser.desktop "NexOS Browser" "Open the NexOS browser" "nexos-browser" "web-browser" "Network;WebBrowser;"
make_desktop /usr/share/applications/nexos-extractor.desktop "NexOS Extractor" "Extract archives with NexOS" "nexos-extractor" "package-x-generic" "Utility;Archiving;"
make_desktop /usr/share/applications/nexos-repair-tools.desktop "NexOS Repair Tools" "Fix common NexOS desktop/session issues" "nexos-repair-tools" "applications-system" "System;Utility;"
make_desktop /usr/share/applications/nexos-update-helper.desktop "NexOS Update Helper" "Check live system package updates" "nexos-update-helper" "system-software-update" "System;"
make_desktop /usr/share/applications/nexos-app-map.desktop "NexOS App Map" "Show NexOS open-source foundations" "nexos-app-map" "text-x-generic" "Documentation;System;"

cat > "/home/$LIVE_USERNAME/.config/autostart/nexos-first-setup.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS First Setup
Exec=nexos-first-setup
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP

for desktop in "NexOS Control Center" "NexOS First Setup" "NexOS Browser" "NexOS Extractor" "NexOS Repair Tools" "NexOS App Map"; do
  src="/usr/share/applications/$(echo "$desktop" | tr '[:upper:] ' '[:lower:]-').desktop"
  # Manual mapping keeps names stable even with spaces.
  case "$desktop" in
    "NexOS Control Center") src=/usr/share/applications/nexos-control-center.desktop ;;
    "NexOS First Setup") src=/usr/share/applications/nexos-first-setup.desktop ;;
    "NexOS Browser") src=/usr/share/applications/nexos-browser.desktop ;;
    "NexOS Extractor") src=/usr/share/applications/nexos-extractor.desktop ;;
    "NexOS Repair Tools") src=/usr/share/applications/nexos-repair-tools.desktop ;;
    "NexOS App Map") src=/usr/share/applications/nexos-app-map.desktop ;;
  esac
  cp -f "$src" "/home/$LIVE_USERNAME/Desktop/$desktop.desktop" || true
  chmod 0755 "/home/$LIVE_USERNAME/Desktop/$desktop.desktop" || true
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
