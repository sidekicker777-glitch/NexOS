#!/usr/bin/env bash
# NexOS desktop/boot overhaul.
# Fixes the ugly startup browser window, empty/gray bottom bar, desktop launcher warnings,
# black wallpaper fallback, and noisy boot console messages.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

NEXOS_EDITION="${NEXOS_EDITION:-main}"
EDITION_LABEL="${EDITION_LABEL:-NexOS Main}"

ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"

cat > "$LB_CONFIG_DIR/package-lists/56-nexos-desktop-overhaul.list.chroot" <<'PKGS'
# NexOS desktop overhaul support.
python3
python3-tk
libglib2.0-bin
x11-xserver-utils
xfconf
xdg-utils
wmctrl
PKGS

cat > "$LB_CONFIG_DIR/hooks/normal/150-nexos-desktop-overhaul.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

LIVE_USERNAME="__LIVE_USERNAME__"
EDITION_LABEL="__EDITION_LABEL__"
home_dir="/home/$LIVE_USERNAME"
xfconf_dir="$home_dir/.config/xfce4/xfconf/xfce-perchannel-xml"
panel_dir="$home_dir/.config/xfce4/panel"

install_if_available() {
  local pkg="$1"
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    apt-get install -y --no-install-recommends "$pkg" || true
  fi
}

apt-get update || true
for pkg in python3 python3-tk libglib2.0-bin x11-xserver-utils xfconf xdg-utils wmctrl; do
  install_if_available "$pkg"
done

mkdir -p /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/Desktop" "$home_dir/.config/autostart" "$xfconf_dir" "$panel_dir"

# Replace the browser-based startup page with a native desktop window.
cat > /usr/local/bin/nexos-startup-center <<'PY'
#!/usr/bin/env python3
from __future__ import annotations
import shutil, subprocess, tkinter as tk
from tkinter import ttk

ACTIONS = [
    ("Control Center", "Main NexOS settings and tools", ["nexos-control-center"]),
    ("Install Center", "Install or test NexOS", ["nexos-install-center"]),
    ("Dev Center", "Code editor and compiler starters", ["nexos-dev-center"]),
    ("Files", "Open the file manager", ["thunar"]),
    ("Browser", "Open the web browser", ["nexos-browser"]),
    ("Terminal", "Open a command terminal", ["xfce4-terminal"]),
    ("Assistant", "Open the NexOS AI assistant", ["nexos-assistant-toggle"]),
    ("Display Help", "Fix VM size and GPU confusion", ["nexos-vm-display-help"]),
]

def run(cmds):
    for raw in cmds:
        exe = raw.split()[0]
        if shutil.which(exe):
            subprocess.Popen(raw.split(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return

root = tk.Tk()
root.title("NexOS Startup Center")
root.geometry("860x520")
root.configure(bg="#07111f")
root.minsize(760, 460)
style = ttk.Style(root)
try:
    style.theme_use("clam")
except Exception:
    pass
style.configure("Card.TButton", font=("Sans", 12, "bold"), padding=12)

wrap = tk.Frame(root, bg="#07111f", padx=34, pady=28)
wrap.pack(fill="both", expand=True)
tk.Label(wrap, text="NexOS", bg="#07111f", fg="#e8f7ff", font=("Sans", 42, "bold")).pack(anchor="w")
tk.Label(wrap, text="Desktop ready. Pick a tool or use the dock.", bg="#07111f", fg="#9bd5ff", font=("Sans", 15)).pack(anchor="w", pady=(0, 20))

grid = tk.Frame(wrap, bg="#07111f")
grid.pack(fill="both", expand=True)
for i, (name, desc, cmds) in enumerate(ACTIONS):
    card = tk.Frame(grid, bg="#0d172b", highlightbackground="#294866", highlightthickness=1, padx=12, pady=10)
    card.grid(row=i//2, column=i%2, padx=8, pady=8, sticky="nsew")
    grid.grid_columnconfigure(i%2, weight=1)
    tk.Label(card, text=name, bg="#0d172b", fg="#e8f7ff", font=("Sans", 14, "bold")).pack(anchor="w")
    tk.Label(card, text=desc, bg="#0d172b", fg="#a7bdd8", font=("Sans", 10), wraplength=330, justify="left").pack(anchor="w", pady=(3, 8))
    ttk.Button(card, text="Open", style="Card.TButton", command=lambda c=cmds: run(c)).pack(anchor="e")

bottom = tk.Frame(wrap, bg="#07111f")
bottom.pack(fill="x", pady=(12, 0))
tk.Label(bottom, text="This startup center no longer opens in Firefox.", bg="#07111f", fg="#7fa4ca", font=("Sans", 10)).pack(side="left")
ttk.Button(bottom, text="Close", command=root.destroy).pack(side="right")
root.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-startup-center

# Reliable native dock. This replaces the broken empty XFCE bottom launcher panel.
cat > /usr/local/bin/nexos-dock <<'PY'
#!/usr/bin/env python3
from __future__ import annotations
import shutil, subprocess, tkinter as tk

BUTTONS = [
    ("NexOS", ["nexos-assistant-toggle", "nexos-startup-center"]),
    ("Control", ["nexos-control-center"]),
    ("Dev", ["nexos-dev-center"]),
    ("Install", ["nexos-install-center"]),
    ("Files", ["thunar"]),
    ("Browser", ["nexos-browser", "firefox-esr"]),
    ("Terminal", ["xfce4-terminal"]),
]

def launch(cmds):
    for raw in cmds:
        exe = raw.split()[0]
        if shutil.which(exe):
            subprocess.Popen(raw.split(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return

root = tk.Tk()
root.title("NexOS Dock")
root.overrideredirect(True)
root.attributes("-topmost", True)
root.configure(bg="#111827")
width, height = 680, 58
sw, sh = root.winfo_screenwidth(), root.winfo_screenheight()
root.geometry(f"{width}x{height}+{max(0,(sw-width)//2)}+{max(0,sh-height-12)}")
frame = tk.Frame(root, bg="#111827", padx=10, pady=8, highlightthickness=1, highlightbackground="#334155")
frame.pack(fill="both", expand=True)
for label, cmds in BUTTONS:
    b = tk.Button(frame, text=label, command=lambda c=cmds: launch(c), bg="#1f2937", fg="#e8f7ff", activebackground="#0ea5e9", activeforeground="#ffffff", relief="flat", padx=14, pady=7, font=("Sans", 10, "bold"))
    b.pack(side="left", padx=4)
root.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-dock

# Finalize desktop at login: set wallpaper on the actual monitor key, remove unsafe custom desktop launchers,
# kill the broken second XFCE panel, and restart the top panel cleanly.
cat > /usr/local/bin/nexos-desktop-finalize <<'BASH'
#!/usr/bin/env bash
set -euo pipefail

wall="/usr/share/backgrounds/nexos/nexos-default.png"

# No custom .desktop files on the desktop: this avoids XFCE's untrusted launcher warnings completely.
mkdir -p "$HOME/.local/share/nexos-hidden-desktop-launchers"
if [[ -d "$HOME/Desktop" ]]; then
  find "$HOME/Desktop" -maxdepth 1 -type f -name '*.desktop' | while read -r file; do
    mv -f "$file" "$HOME/.local/share/nexos-hidden-desktop-launchers/$(basename "$file")" 2>/dev/null || rm -f "$file"
  done
fi

# Trust any remaining launchers in panel/app dirs.
if command -v gio >/dev/null 2>&1; then
  for dir in "$HOME/Desktop" "$HOME/.config/xfce4/panel"; do
    [[ -d "$dir" ]] || continue
    find "$dir" -type f -name '*.desktop' | while read -r file; do
      chmod 0755 "$file" 2>/dev/null || true
      gio set "$file" metadata::trusted true 2>/dev/null || true
    done
  done
fi

# Force wallpaper onto whatever monitor name XFCE created.
if [[ -f "$wall" ]] && command -v xfconf-query >/dev/null 2>&1; then
  existing="$(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -E '/last-image$' || true)"
  if [[ -n "$existing" ]]; then
    echo "$existing" | while read -r prop; do
      xfconf-query -c xfce4-desktop -p "$prop" -s "$wall" 2>/dev/null || true
      style="${prop%/last-image}/image-style"
      xfconf-query -c xfce4-desktop -p "$style" -n -t int -s 5 2>/dev/null || true
    done
  fi
  for monitor in monitor0 monitor1 monitorVirtual-1 monitorVirtual1 monitorVirtual-2 monitorVGA-1 monitorVGA1 monitorVirtualBox; do
    xfconf-query -c xfce4-desktop -p "/backdrop/screen0/$monitor/workspace0/last-image" -n -t string -s "$wall" 2>/dev/null || true
    xfconf-query -c xfce4-desktop -p "/backdrop/screen0/$monitor/workspace0/image-style" -n -t int -s 5 2>/dev/null || true
  done
fi

# Remove the second XFCE bottom panel so the native NexOS dock is the only bottom bar.
if command -v xfconf-query >/dev/null 2>&1; then
  xfconf-query -c xfce4-panel -p /panels -n -t int -s 1 2>/dev/null || true
  xfconf-query -c xfce4-panel -p /panels/panel-2 -r -R 2>/dev/null || true
fi

xfdesktop --reload >/dev/null 2>&1 || true
xfce4-panel --restart >/dev/null 2>&1 || true
BASH
chmod 0755 /usr/local/bin/nexos-desktop-finalize

# Top panel only. Bottom dock is handled by nexos-dock, not fragile XFCE launcher plugins.
cat > "$xfconf_dir/xfce4-panel.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=6;x=0;y=0"/>
      <property name="length" type="uint" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="size" type="uint" value="32"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="10"/>
        <value type="int" value="11"/>
        <value type="int" value="12"/>
        <value type="int" value="13"/>
        <value type="int" value="14"/>
        <value type="int" value="15"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-10" type="string" value="systray"/>
    <property name="plugin-11" type="string" value="pulseaudio"/>
    <property name="plugin-12" type="string" value="clock">
      <property name="digital-format" type="string" value="%Y-%m-%d  %H:%M"/>
    </property>
    <property name="plugin-13" type="string" value="actions"/>
    <property name="plugin-14" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-15" type="string" value="whiskermenu">
      <property name="button-title" type="string" value="Applications"/>
      <property name="show-button-title" type="bool" value="true"/>
    </property>
  </property>
</channel>
XML

# No auto Firefox/browser startup. Dock + assistant orb start automatically. Startup Center is opened manually from dock/menu.
rm -f "$home_dir/.config/autostart/nexos-startup-center.desktop" 2>/dev/null || true
cat > "$home_dir/.config/autostart/nexos-desktop-finalize.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Desktop Finalize
Exec=sh -c 'sleep 2; nexos-desktop-finalize'
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP
cat > "$home_dir/.config/autostart/nexos-dock.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Dock
Exec=sh -c 'sleep 3; nexos-dock'
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP

# Remove desktop launchers now too.
find "$home_dir/Desktop" -maxdepth 1 -type f -name '*.desktop' -delete 2>/dev/null || true

cat > /usr/share/applications/nexos-startup-center.desktop <<'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=NexOS Startup Center
Comment=Native NexOS startup center
Exec=nexos-startup-center
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-startup.svg
Terminal=false
StartupNotify=false
Categories=System;Settings;
X-XFCE-Trusted=true
DESKTOP
chmod 0755 /usr/share/applications/nexos-startup-center.desktop

cat > /usr/share/applications/nexos-dock.desktop <<'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=NexOS Dock
Comment=NexOS bottom dock
Exec=nexos-dock
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-startup.svg
Terminal=false
StartupNotify=false
Categories=System;
X-XFCE-Trusted=true
DESKTOP
chmod 0755 /usr/share/applications/nexos-dock.desktop

cat >> /usr/share/nexos/app-map.txt <<'APPMAP_APPEND'

NexOS Desktop Overhaul:
- Replaces browser startup page with a native Tk startup center.
- Removes custom desktop .desktop launchers to stop XFCE untrusted launcher warnings.
- Replaces the broken XFCE bottom panel with a native NexOS dock.
- Applies wallpaper at login against whatever monitor key VirtualBox exposes.
- Keeps a single clean top panel with Applications on the right.
APPMAP_APPEND

chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel
rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK

sed -i \
  -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" \
  -e "s/__EDITION_LABEL__/$EDITION_LABEL/g" \
  "$LB_CONFIG_DIR/hooks/normal/150-nexos-desktop-overhaul.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/150-nexos-desktop-overhaul.hook.chroot"

cat > "$LB_CONFIG_DIR/hooks/normal/990-nexos-quiet-boot-theme.hook.binary" <<'BINARYHOOK'
#!/usr/bin/env bash
set -euo pipefail

# Tiny dark PNG for syslinux background. Makes the boot menu dark instead of gray.
png_b64='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='
find . -type d \( -iname 'isolinux' -o -iname 'syslinux' \) 2>/dev/null | while read -r dir; do
  printf '%s' "$png_b64" | base64 -d > "$dir/splash.png" 2>/dev/null || true
  for cfg in "$dir"/*.cfg; do
    [[ -f "$cfg" ]] || continue
    grep -qi '^menu background' "$cfg" || sed -i '1i MENU BACKGROUND splash.png' "$cfg" || true
    grep -qi '^menu color screen' "$cfg" || cat >> "$cfg" <<'EOF'
MENU COLOR screen 37;40 #ff0b1020 #ff0b1020 none
MENU COLOR border 37;40 #ff0b1020 #ff0b1020 none
MENU COLOR title 1;36;40 #ff38bdf8 #ff0b1020 none
MENU COLOR sel 7;37;40 #ffffffff #ff1d4ed8 none
MENU COLOR unsel 37;40 #ffe8f7ff #ff0b1020 none
MENU COLOR help 37;40 #ff9bd5ff #ff0b1020 none
MENU COLOR timeout_msg 37;40 #ff9bd5ff #ff0b1020 none
MENU COLOR timeout 1;37;40 #ffffffff #ff0b1020 none
EOF
  done
done

quiet_args='quiet splash loglevel=3 systemd.show_status=false rd.udev.log_level=3 vt.global_cursor_default=0 plymouth.ignore-serial-consoles'
find . -type f \( -name '*.cfg' -o -name '*.txt' -o -name '*.conf' \) 2>/dev/null | while read -r file; do
  sed -i -E \
    -e 's/Debian GNU\/Linux[[:space:]]+[0-9][^)]*\([^)]+\)[[:space:]]+amd64/NexOS Origin amd64/g' \
    -e 's/Debian GNU\/Linux[[:space:]]+[0-9][^)]*\([^)]+\)/NexOS Origin/g' \
    -e 's/Debian GNU\/Linux/NexOS/g' \
    -e 's/Live system/NexOS Live Desktop/g' \
    "$file" || true
  if grep -Eq '^[[:space:]]*(append|linuxefi|linux)[[:space:]]' "$file"; then
    sed -i -E "/^[[:space:]]*(append|linuxefi|linux)[[:space:]]/ { /loglevel=3/! s/$/ $quiet_args/ }" "$file" || true
  fi
done

mkdir -p binary/.nexos 2>/dev/null || true
cat > binary/.nexos/quiet-boot-theme.txt <<'MARKER'
NexOS quiet boot and dark boot menu theme applied.
MARKER
BINARYHOOK
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/990-nexos-quiet-boot-theme.hook.binary"

success "Injected NexOS desktop overhaul for $NEXOS_EDITION."
