#!/usr/bin/env bash
# Final NexOS UI fix pass.
# Fixes missing icons, ugly dock placeholders, and XFCE untrusted launcher warnings.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

NEXOS_EDITION="${NEXOS_EDITION:-main}"
EDITION_LABEL="${EDITION_LABEL:-NexOS Main}"

ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"

cat > "$LB_CONFIG_DIR/package-lists/53-nexos-ui-final-fix.list.chroot" <<'PKGS'
# Final NexOS UI fix support.
libglib2.0-bin
shared-mime-info
hicolor-icon-theme
PKGS

cat > "$LB_CONFIG_DIR/hooks/normal/130-nexos-ui-final-fix.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

LIVE_USERNAME="__LIVE_USERNAME__"
EDITION_LABEL="__EDITION_LABEL__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
panel_dir="$home_dir/.config/xfce4/panel"
xfconf_dir="$home_dir/.config/xfce4/xfconf/xfce-perchannel-xml"

install_if_available() {
  local pkg="$1"
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    apt-get install -y --no-install-recommends "$pkg" || true
  fi
}

apt-get update || true
for pkg in libglib2.0-bin shared-mime-info hicolor-icon-theme papirus-icon-theme arc-theme firefox-esr; do
  install_if_available "$pkg"
done

mkdir -p "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/Desktop" "$home_dir/.config/autostart" "$panel_dir" "$xfconf_dir"

make_icon() {
  local name="$1" accent="$2" symbol="$3"
  cat > "$icon_dir/$name.svg" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#101827"/><stop offset="1" stop-color="#020617"/></linearGradient>
    <linearGradient id="fg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="$accent"/><stop offset="1" stop-color="#dff7ff"/></linearGradient>
  </defs>
  <rect x="9" y="9" width="110" height="110" rx="26" fill="url(#bg)" stroke="$accent" stroke-width="4"/>
  <circle cx="96" cy="31" r="9" fill="$accent" opacity=".9"/>
  <text x="64" y="77" text-anchor="middle" font-family="DejaVu Sans, Arial, sans-serif" font-size="36" font-weight="800" fill="url(#fg)">$symbol</text>
</svg>
SVG
}

make_icon nexos-startup '#38bdf8' 'NX'
make_icon nexos-control '#38bdf8' '⚙'
make_icon nexos-install '#22c55e' '↓'
make_icon nexos-dev '#a78bfa' '&lt;/&gt;'
make_icon nexos-help '#facc15' '?'
make_icon nexos-power '#fb7185' '⏻'
make_icon nexos-gpu '#2dd4bf' 'GPU'
make_icon nexos-files '#93c5fd' 'DIR'
make_icon nexos-web '#34d399' 'WEB'
make_icon nexos-terminal '#c084fc' '$_'

icon_abs() { printf '/usr/share/icons/hicolor/scalable/apps/%s.svg' "$1"; }

cat > /usr/local/bin/nexos-browser <<'BROWSER'
#!/usr/bin/env bash
set -euo pipefail
if command -v firefox-esr >/dev/null 2>&1; then exec firefox-esr "$@"; fi
if command -v firefox >/dev/null 2>&1; then exec firefox "$@"; fi
exec xdg-open "${1:-https://www.debian.org}"
BROWSER
chmod 0755 /usr/local/bin/nexos-browser

cat > /usr/local/bin/nexos-startup-center <<'STARTUP'
#!/usr/bin/env bash
set -euo pipefail
html="$HOME/.cache/nexos-startup.html"
mkdir -p "$(dirname "$html")"
cat > "$html" <<'HTML'
<!doctype html><html><head><meta charset="utf-8"><title>NexOS Startup</title>
<style>
body{margin:0;background:radial-gradient(circle at 20% 80%,#25165a 0 24%,transparent 25%),radial-gradient(circle at 82% 18%,#15304d 0 22%,transparent 23%),#080d1c;color:#e8f7ff;font-family:system-ui,Segoe UI,sans-serif;min-height:100vh;display:grid;place-items:center}main{width:min(900px,90vw);padding:34px;border:1px solid #284569;border-radius:26px;background:#0d1529cc;box-shadow:0 25px 80px #0008}h1{font-size:64px;margin:0 0 8px}.sub{color:#9bd5ff;font-size:22px;margin-bottom:28px}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px}.card{padding:18px;border-radius:18px;background:#13213b;border:1px solid #254366}.card b{display:block;font-size:18px;margin-bottom:6px}.card span{color:#a8bdd8;font-size:14px}.hint{margin-top:25px;color:#7fa4ca;font-size:13px}@media(max-width:800px){.grid{grid-template-columns:1fr}h1{font-size:42px}}
</style></head><body><main><h1>NexOS</h1><div class="sub">Clean live desktop loaded.</div><div class="grid">
<div class="card"><b>Control Center</b><span>Main NexOS settings and tools.</span></div>
<div class="card"><b>Install Center</b><span>Install/test NexOS in VirtualBox.</span></div>
<div class="card"><b>Dev Center</b><span>Code editor and compiler starters.</span></div>
<div class="card"><b>Files</b><span>Browse your live system.</span></div>
<div class="card"><b>Browser</b><span>Open the web browser.</span></div>
<div class="card"><b>VM Display Help</b><span>Fix size, scaling, and GPU confusion.</span></div>
</div><div class="hint">Use the dock at the bottom or the Applications menu on the top-right.</div></main></body></html>
HTML
nexos-browser "file://$html" >/dev/null 2>&1 &
STARTUP
chmod 0755 /usr/local/bin/nexos-startup-center

write_desktop() {
  local file="$1" name="$2" exec_cmd="$3" icon="$4" cats="$5"
  cat > "$file" <<DESKTOP
[Desktop Entry]
Version=1.0
Type=Application
Name=$name
Comment=$name
Exec=$exec_cmd
Icon=$icon
Terminal=false
StartupNotify=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
  chmod 0755 "$file"
}

write_desktop /usr/share/applications/nexos-startup-center.desktop "NexOS Startup Center" "nexos-startup-center" "$(icon_abs nexos-startup)" "System;"
write_desktop /usr/share/applications/nexos-control-center.desktop "NexOS Control Center" "nexos-control-center" "$(icon_abs nexos-control)" "System;Settings;"
write_desktop /usr/share/applications/nexos-install-center.desktop "NexOS Install Center" "nexos-install-center" "$(icon_abs nexos-install)" "System;Settings;"
write_desktop /usr/share/applications/nexos-dev-center.desktop "NexOS Dev Center" "nexos-dev-center" "$(icon_abs nexos-dev)" "Development;"
write_desktop /usr/share/applications/nexos-vm-display-help.desktop "NexOS VM Display Help" "nexos-vm-display-help" "$(icon_abs nexos-gpu)" "System;"
write_desktop /usr/share/applications/nexos-browser.desktop "NexOS Browser" "nexos-browser" "$(icon_abs nexos-web)" "Network;WebBrowser;"
write_desktop /usr/share/applications/nexos-files.desktop "NexOS Files" "thunar" "$(icon_abs nexos-files)" "System;FileManager;"
write_desktop /usr/share/applications/nexos-terminal.desktop "NexOS Terminal" "xfce4-terminal" "$(icon_abs nexos-terminal)" "System;TerminalEmulator;"

# Clean desktop and only keep the main NexOS launchers.
mkdir -p "$home_dir/.local/share/nexos-hidden-desktop-launchers"
find "$home_dir/Desktop" -maxdepth 1 -type f -name '*.desktop' | while read -r file; do
  mv -f "$file" "$home_dir/.local/share/nexos-hidden-desktop-launchers/$(basename "$file")" 2>/dev/null || rm -f "$file"
done
for pair in \
  "nexos-startup-center.desktop|NexOS Startup Center.desktop" \
  "nexos-control-center.desktop|NexOS Control Center.desktop" \
  "nexos-install-center.desktop|NexOS Install Center.desktop" \
  "nexos-dev-center.desktop|NexOS Dev Center.desktop" \
  "nexos-vm-display-help.desktop|NexOS VM Display Help.desktop"; do
  src="${pair%%|*}"; dst="${pair#*|}"
  cp -f "/usr/share/applications/$src" "$home_dir/Desktop/$dst"
done
chmod 0755 "$home_dir/Desktop"/*.desktop 2>/dev/null || true

cat > /usr/local/bin/nexos-trust-launchers <<'TRUST'
#!/usr/bin/env bash
set -euo pipefail
for dir in "$HOME/Desktop" "$HOME/.config/xfce4/panel"; do
  [[ -d "$dir" ]] || continue
  find "$dir" -type f -name '*.desktop' | while read -r file; do
    chmod 0755 "$file" 2>/dev/null || true
    command -v gio >/dev/null 2>&1 && gio set "$file" metadata::trusted true 2>/dev/null || true
  done
done
TRUST
chmod 0755 /usr/local/bin/nexos-trust-launchers

cat > "$home_dir/.config/autostart/nexos-trust-launchers.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Trust Launchers
Exec=sh -c 'sleep 1; nexos-trust-launchers'
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP

cat > "$home_dir/.config/autostart/nexos-startup-center.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Startup Center
Exec=sh -c 'sleep 4; nexos-trust-launchers; nexos-startup-center'
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP

cat > "$xfconf_dir/xsettings.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty"><property name="ThemeName" type="string" value="Arc-Dark"/><property name="IconThemeName" type="string" value="hicolor"/></property>
  <property name="Gtk" type="empty"><property name="FontName" type="string" value="Noto Sans 11"/><property name="MonospaceFontName" type="string" value="DejaVu Sans Mono 11"/></property>
</channel>
XML

rm -rf "$panel_dir"/launcher-* 2>/dev/null || true
for id in 30 31 32 33 34 35; do mkdir -p "$panel_dir/launcher-$id"; done
cp -f /usr/share/applications/nexos-startup-center.desktop "$panel_dir/launcher-30/nexos-startup-center.desktop"
cp -f /usr/share/applications/nexos-control-center.desktop "$panel_dir/launcher-31/nexos-control-center.desktop"
cp -f /usr/share/applications/nexos-dev-center.desktop "$panel_dir/launcher-32/nexos-dev-center.desktop"
cp -f /usr/share/applications/nexos-install-center.desktop "$panel_dir/launcher-33/nexos-install-center.desktop"
cp -f /usr/share/applications/nexos-browser.desktop "$panel_dir/launcher-34/nexos-browser.desktop"
cp -f /usr/share/applications/nexos-files.desktop "$panel_dir/launcher-35/nexos-files.desktop"
chmod 0755 "$panel_dir"/launcher-*/*.desktop 2>/dev/null || true

cat > "$xfconf_dir/xfce4-panel.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/><value type="int" value="2"/>
    <property name="panel-1" type="empty"><property name="position" type="string" value="p=6;x=0;y=0"/><property name="length" type="uint" value="100"/><property name="position-locked" type="bool" value="true"/><property name="size" type="uint" value="30"/><property name="plugin-ids" type="array"><value type="int" value="10"/><value type="int" value="11"/><value type="int" value="12"/><value type="int" value="13"/><value type="int" value="14"/><value type="int" value="15"/></property></property>
    <property name="panel-2" type="empty"><property name="position" type="string" value="p=10;x=0;y=0"/><property name="length" type="uint" value="30"/><property name="position-locked" type="bool" value="true"/><property name="size" type="uint" value="58"/><property name="plugin-ids" type="array"><value type="int" value="30"/><value type="int" value="31"/><value type="int" value="32"/><value type="int" value="33"/><value type="int" value="34"/><value type="int" value="35"/></property></property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-10" type="string" value="systray"/><property name="plugin-11" type="string" value="pulseaudio"/><property name="plugin-12" type="string" value="clock"><property name="digital-format" type="string" value="%Y-%m-%d  %H:%M"/></property><property name="plugin-13" type="string" value="actions"/><property name="plugin-14" type="string" value="separator"><property name="expand" type="bool" value="true"/><property name="style" type="uint" value="0"/></property><property name="plugin-15" type="string" value="whiskermenu"><property name="button-title" type="string" value="Applications"/><property name="button-icon" type="string" value="/usr/share/icons/hicolor/scalable/apps/nexos-startup.svg"/><property name="show-button-title" type="bool" value="true"/></property>
    <property name="plugin-30" type="string" value="launcher"><property name="items" type="array"><value type="string" value="nexos-startup-center.desktop"/></property></property>
    <property name="plugin-31" type="string" value="launcher"><property name="items" type="array"><value type="string" value="nexos-control-center.desktop"/></property></property>
    <property name="plugin-32" type="string" value="launcher"><property name="items" type="array"><value type="string" value="nexos-dev-center.desktop"/></property></property>
    <property name="plugin-33" type="string" value="launcher"><property name="items" type="array"><value type="string" value="nexos-install-center.desktop"/></property></property>
    <property name="plugin-34" type="string" value="launcher"><property name="items" type="array"><value type="string" value="nexos-browser.desktop"/></property></property>
    <property name="plugin-35" type="string" value="launcher"><property name="items" type="array"><value type="string" value="nexos-files.desktop"/></property></property>
  </property>
</channel>
XML

if command -v gtk-update-icon-cache >/dev/null 2>&1; then gtk-update-icon-cache -f /usr/share/icons/hicolor >/dev/null 2>&1 || true; fi

chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel
rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK

sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" -e "s/__EDITION_LABEL__/$EDITION_LABEL/g" "$LB_CONFIG_DIR/hooks/normal/130-nexos-ui-final-fix.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/130-nexos-ui-final-fix.hook.chroot"

success "Injected final NexOS UI fixes for $NEXOS_EDITION."
