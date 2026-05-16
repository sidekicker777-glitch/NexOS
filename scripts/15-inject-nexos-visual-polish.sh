#!/usr/bin/env bash
# Injects NexOS visual polish and VM display fixes.
# Goal: stop the ISO from looking tiny/cluttered in VirtualBox and make the desktop cleaner.
# This script also chains boot-branding, icon-fix, desktop layout, and final UI fix injectors.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

NEXOS_EDITION="${NEXOS_EDITION:-main}"
EDITION_LABEL="${EDITION_LABEL:-NexOS Main}"

ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"

cat > "$LB_CONFIG_DIR/package-lists/49-nexos-visual-polish-tools.list.chroot" <<'PKGS'
# NexOS visual polish dependencies.
feh
imagemagick
x11-xserver-utils
xfconf
PKGS

cat > "$LB_CONFIG_DIR/hooks/normal/090-nexos-visual-polish.hook.chroot" <<'HOOK'
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
for pkg in feh imagemagick x11-xserver-utils xfconf virtualbox-guest-x11 virtualbox-guest-utils qemu-guest-agent spice-vdagent xserver-xorg-video-vmware xserver-xorg-video-qxl; do
  install_if_available "$pkg"
done

mkdir -p /usr/local/bin /usr/share/applications /usr/share/backgrounds/nexos "$home_dir/Desktop" "$home_dir/.config/autostart" "$home_dir/.config/xfce4/xfconf/xfce-perchannel-xml"

if command -v convert >/dev/null 2>&1; then
  convert -size 1920x1080 gradient:'#07111f-#101827' \
    -fill '#0fd3ff' -draw 'rectangle 0,0 1920,5' \
    -fill 'rgba(15,211,255,0.16)' -draw 'circle 1560,260 1870,260' \
    -fill 'rgba(120,80,255,0.16)' -draw 'circle 360,820 720,820' \
    -fill '#e8f7ff' -gravity center -pointsize 86 -font DejaVu-Sans-Bold -annotate +0-30 'NexOS' \
    -fill '#7ccfff' -gravity center -pointsize 26 -font DejaVu-Sans -annotate +0+55 "$EDITION_LABEL" \
    /usr/share/backgrounds/nexos/nexos-default.png || true
fi

cat > /usr/local/bin/nexos-display-fix <<'DISPLAYFIX'
#!/usr/bin/env bash
set -euo pipefail
if ! command -v xrandr >/dev/null 2>&1; then exit 0; fi
connected_outputs="$(xrandr --query | awk '/ connected/{print $1}')"
[[ -n "$connected_outputs" ]] || exit 0
for out in $connected_outputs; do
  modes="$(xrandr --query | awk -v o="$out" '$1==o{show=1; next} /^[A-Za-z0-9-]+ connected/{show=0} show && $1 ~ /^[0-9]+x[0-9]+/{print $1}')"
  preferred=""
  for candidate in 1920x1080 1600x900 1440x900 1366x768 1280x800 1280x720 1024x768; do
    if echo "$modes" | grep -qx "$candidate"; then preferred="$candidate"; break; fi
  done
  if [[ -n "$preferred" ]]; then
    xrandr --output "$out" --mode "$preferred" >/dev/null 2>&1 || true
  fi
done
xfconf-query -c xsettings -p /Gtk/FontName -s 'Noto Sans 11' 2>/dev/null || true
xfconf-query -c xsettings -p /Gtk/MonospaceFontName -s 'DejaVu Sans Mono 11' 2>/dev/null || true
xfconf-query -c xfce4-desktop -p /desktop-icons/icon-size -s 56 2>/dev/null || true
DISPLAYFIX
chmod 0755 /usr/local/bin/nexos-display-fix

cat > /usr/local/bin/nexos-clean-desktop <<'CLEAN'
#!/usr/bin/env bash
set -euo pipefail
desktop="$HOME/Desktop"
mkdir -p "$desktop" "$HOME/.local/share/nexos-hidden-desktop-launchers"
find "$desktop" -maxdepth 1 -type f -name '*.desktop' | while read -r file; do
  base="$(basename "$file")"
  case "$base" in
    "NexOS Control Center.desktop"|"NexOS Install Center.desktop"|"NexOS Dev Center.desktop"|"NexOS Help.desktop"|"NexOS Power.desktop"|"NexOS Startup Center.desktop"|"NexOS VM Display Help.desktop") ;;
    *) mv -f "$file" "$HOME/.local/share/nexos-hidden-desktop-launchers/$base" 2>/dev/null || rm -f "$file" ;;
  esac
done
CLEAN
chmod 0755 /usr/local/bin/nexos-clean-desktop

cat > /usr/local/bin/nexos-visual-setup <<'VISUAL'
#!/usr/bin/env bash
set -euo pipefail
nexos-display-fix || true
nexos-clean-desktop || true
nexos-trust-launchers || true
if [[ -f /usr/share/backgrounds/nexos/nexos-default.png ]]; then
  for monitor in monitorVirtual-1 monitorVirtual1 monitor0 monitorVGA-1; do
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/$monitor/workspace0/last-image -n -t string -s /usr/share/backgrounds/nexos/nexos-default.png 2>/dev/null || true
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/$monitor/workspace0/image-style -n -t int -s 5 2>/dev/null || true
  done
fi
VISUAL
chmod 0755 /usr/local/bin/nexos-visual-setup

cat > "$home_dir/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="desktop-icons" type="empty">
    <property name="style" type="int" value="2"/>
    <property name="icon-size" type="uint" value="56"/>
    <property name="font-size" type="double" value="11.000000"/>
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

cat > "$home_dir/.config/autostart/nexos-visual-setup.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Visual Setup
Exec=nexos-visual-setup
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP

HOME="$home_dir" /usr/local/bin/nexos-clean-desktop || true

cat >> /usr/share/nexos/app-map.txt <<'APPMAP_APPEND'

Visual polish:
- NexOS Visual Setup: first-login resolution, desktop cleanup, and wallpaper helper.
- NexOS Display Fix: tries to pick a readable VM resolution using xrandr.
- NexOS Clean Desktop: hides extra shortcuts so the desktop looks cleaner.
APPMAP_APPEND

chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel
rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK

sed -i \
  -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" \
  -e "s/__NEXOS_EDITION__/$NEXOS_EDITION/g" \
  -e "s/__EDITION_LABEL__/$EDITION_LABEL/g" \
  "$LB_CONFIG_DIR/hooks/normal/090-nexos-visual-polish.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/090-nexos-visual-polish.hook.chroot"

# Chain late-stage polish injectors.
bash "$SCRIPT_DIR/16-inject-nexos-branding-boot.sh"
bash "$SCRIPT_DIR/17-inject-nexos-icons-fix.sh"
bash "$SCRIPT_DIR/18-inject-nexos-desktop-layout.sh"
bash "$SCRIPT_DIR/20-inject-nexos-ui-final-fix.sh"

success "Injected NexOS visual polish, branding, icons, desktop layout, and final UI fixes for $NEXOS_EDITION."
