#!/usr/bin/env bash
# NexOS Branding v2: wallpapers, login background config, release labels, branding center.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
EDITION_LABEL="${EDITION_LABEL:-NexOS Main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/73-nexos-branding-v2.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
imagemagick
lightdm
lightdm-gtk-greeter
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/320-nexos-branding-v2.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
EDITION_LABEL="__EDITION_LABEL__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin imagemagick lightdm lightdm-gtk-greeter; do install_if_available "$p"; done
mkdir -p /opt/nexos/branding "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos /usr/share/backgrounds/nexos /etc/lightdm/lightdm-gtk-greeter.conf.d "$home_dir/.config/autostart"
cat > "$icon_dir/nexos-branding.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><path d="M35 91V37l58 54V37" fill="none" stroke="#e8f7ff" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/><circle cx="96" cy="31" r="8" fill="#22c55e"/></svg>
SVG
if command -v convert >/dev/null 2>&1; then
  convert -size 1920x1080 gradient:'#020617-#111827' -fill '#e8f7ff' -gravity center -pointsize 96 -font DejaVu-Sans-Bold -annotate +0-36 'NexOS' -fill '#7dd3fc' -gravity center -pointsize 30 -font DejaVu-Sans -annotate +0+56 "$EDITION_LABEL" -fill '#22c55e' -draw 'rectangle 0,0 1920,6' /usr/share/backgrounds/nexos/nexos-branding-v2.png || true
  convert -size 1920x1080 gradient:'#050816-#0f172a' -fill '#e8f7ff' -gravity center -pointsize 86 -font DejaVu-Sans-Bold -annotate +0-25 'Welcome to NexOS' -fill '#7dd3fc' -gravity center -pointsize 28 -font DejaVu-Sans -annotate +0+50 'Your OS. Your tools. Your workspace.' /usr/share/backgrounds/nexos/nexos-login-v2.png || true
fi
cat > /etc/issue <<'ISSUE'
NexOS \n \l
ISSUE
cat > /etc/issue.net <<'ISSUE'
NexOS
ISSUE
cat > /usr/share/nexos/nexos-release <<REL
NAME="NexOS"
PRETTY_NAME="$EDITION_LABEL"
NEXOS_BRANDING_VERSION="2"
REL
cat > /etc/lightdm/lightdm-gtk-greeter.conf.d/60-nexos-branding.conf <<'CONF'
[greeter]
background=/usr/share/backgrounds/nexos/nexos-login-v2.png
theme-name=Arc-Dark
icon-theme-name=hicolor
font-name=Noto Sans 11
CONF
cat > /usr/local/bin/nexos-apply-branding <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
if [[ -f /usr/share/backgrounds/nexos/nexos-branding-v2.png ]]; then
  for monitor in monitorVirtual-1 monitorVirtual1 monitor0 monitorVGA-1; do
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/$monitor/workspace0/last-image -n -t string -s /usr/share/backgrounds/nexos/nexos-branding-v2.png 2>/dev/null || true
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/$monitor/workspace0/image-style -n -t int -s 5 2>/dev/null || true
  done
fi
notify-send "NexOS Branding" "NexOS branding applied" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-apply-branding
cat > /usr/local/bin/nexos-branding-center <<'PY'
#!/usr/bin/env python3
import shutil, subprocess, tkinter as tk
from tkinter import messagebox
A=[('Apply NexOS Branding','nexos-apply-branding'),('Theme Center','nexos-theme-center'),('Settings','nexos-settings'),('Wallpapers','xdg-open /usr/share/backgrounds/nexos'),('Release Info','x-terminal-emulator -e cat /usr/share/nexos/nexos-release')]
def run(c):
    e=c.split()[0]
    if shutil.which(e): subprocess.Popen(c.split(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    else: messagebox.showwarning('NexOS Branding Center',f'{e} is not installed.')
r=tk.Tk(); r.title('NexOS Branding Center'); r.geometry('760x470'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Branding Center',bg='#07111f',fg='#e8f7ff',font=('Sans',30,'bold')).pack(anchor='w',padx=24,pady=18)
f=tk.Frame(r,bg='#07111f',padx=22); f.pack(fill='both',expand=True)
for n,c in A: tk.Button(f,text=n,command=lambda x=c:run(x),bg='#1f2937',fg='#e8f7ff',activebackground='#0ea5e9',relief='flat',padx=18,pady=13,font=('Sans',12,'bold')).pack(fill='x',pady=6)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-branding-center
cat > "$home_dir/.config/autostart/nexos-apply-branding.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Apply Branding
Exec=nexos-apply-branding
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP
cat > /usr/share/applications/nexos-branding-center.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Branding Center
Exec=nexos-branding-center
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-branding.svg
Terminal=false
Categories=Settings;DesktopSettings;
X-XFCE-Trusted=true
DESKTOP
chmod 0755 /usr/share/applications/nexos-branding-center.desktop
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-branding-center' not in s: p.write_text(s.replace('\n]', '\n    ("Branding", ["nexos-branding-center"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('branding center','nexos-branding-center','NexOS Branding Center'),('apply branding','nexos-apply-branding','NexOS Apply Branding')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Branding v2:
- Adds NexOS wallpapers, login background config, issue labels, release marker, branding center, autostart wallpaper application, dock/menu entries, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" -e "s/__EDITION_LABEL__/$EDITION_LABEL/g" "$LB_CONFIG_DIR/hooks/normal/320-nexos-branding-v2.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/320-nexos-branding-v2.hook.chroot"
success "Injected NexOS Branding v2 for $NEXOS_EDITION."
