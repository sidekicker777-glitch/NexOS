#!/usr/bin/env bash
# NexOS Personalization Center: wallpapers, themes, icons, dock/panel layout, fonts, accent color and branding shortcuts.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/83-nexos-personalization-center.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
xfconf
xfce4-settings
x11-xserver-utils
imagemagick
fontconfig
arc-theme
papirus-icon-theme
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/420-nexos-personalization-center.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin xfconf xfce4-settings x11-xserver-utils imagemagick fontconfig arc-theme papirus-icon-theme; do install_if_available "$p"; done
mkdir -p /opt/nexos/personalization-center "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos /usr/share/backgrounds/nexos "$home_dir/.config/nexos/personalization" "$home_dir/NexOS/Wallpapers" "$home_dir/NexOS/Reports"
cat > "$icon_dir/nexos-personalization.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><path d="M34 91h60a8 8 0 0 0 8-8V43a8 8 0 0 0-8-8H34a8 8 0 0 0-8 8v40a8 8 0 0 0 8 8z" fill="none" stroke="#e8f7ff" stroke-width="7"/><circle cx="49" cy="52" r="7" fill="#22c55e"/><path d="M34 82l19-19 14 13 15-19 17 25" fill="none" stroke="#38bdf8" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/></svg>
SVG
if command -v convert >/dev/null 2>&1; then
  convert -size 1920x1080 gradient:'#020617-#0f172a' -fill 'rgba(56,189,248,0.18)' -draw 'circle 1500,240 1900,240' -fill '#e8f7ff' -gravity center -pointsize 88 -font DejaVu-Sans-Bold -annotate +0-25 'NexOS' -fill '#38bdf8' -gravity center -pointsize 28 -font DejaVu-Sans -annotate +0+52 'Dark Core' /usr/share/backgrounds/nexos/nexos-dark-core.png || true
  convert -size 1920x1080 gradient:'#111827-#0b1020' -fill 'rgba(34,197,94,0.18)' -draw 'circle 410,800 780,800' -fill '#e8f7ff' -gravity center -pointsize 88 -font DejaVu-Sans-Bold -annotate +0-25 'NexOS' -fill '#22c55e' -gravity center -pointsize 28 -font DejaVu-Sans -annotate +0+52 'Green Matrix' /usr/share/backgrounds/nexos/nexos-green-matrix.png || true
  convert -size 1920x1080 gradient:'#160b2e-#020617' -fill 'rgba(167,139,250,0.22)' -draw 'circle 1500,260 1880,260' -fill '#e8f7ff' -gravity center -pointsize 88 -font DejaVu-Sans-Bold -annotate +0-25 'NexOS' -fill '#a78bfa' -gravity center -pointsize 28 -font DejaVu-Sans -annotate +0+52 'Purple Neon' /usr/share/backgrounds/nexos/nexos-purple-neon.png || true
fi
cat > /usr/local/bin/nexos-wallpaper-set <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
img="${1:-/usr/share/backgrounds/nexos/nexos-dark-core.png}"
[[ -f "$img" ]] || { echo "Wallpaper not found: $img"; exit 1; }
for p in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep last-image || true); do
  xfconf-query -c xfce4-desktop -p "$p" -s "$img" 2>/dev/null || true
done
for monitor in monitorVirtual-1 monitorVirtual1 monitor0 monitorVGA-1; do
  xfconf-query -c xfce4-desktop -p /backdrop/screen0/$monitor/workspace0/last-image -n -t string -s "$img" 2>/dev/null || true
  xfconf-query -c xfce4-desktop -p /backdrop/screen0/$monitor/workspace0/image-style -n -t int -s 5 2>/dev/null || true
done
notify-send "NexOS Personalization" "Wallpaper applied" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-wallpaper-set
cat > /usr/local/bin/nexos-theme-apply <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
profile="${1:-dark}"
mkdir -p "$HOME/.config/nexos/personalization"
echo "$profile" > "$HOME/.config/nexos/personalization/theme"
case "$profile" in
 dark)
  xfconf-query -c xsettings -p /Net/ThemeName -n -t string -s "Arc-Dark" 2>/dev/null || true
  xfconf-query -c xsettings -p /Net/IconThemeName -n -t string -s "Papirus-Dark" 2>/dev/null || true
  nexos-wallpaper-set /usr/share/backgrounds/nexos/nexos-dark-core.png >/dev/null 2>&1 || true
  ;;
 green)
  xfconf-query -c xsettings -p /Net/ThemeName -n -t string -s "Arc-Dark" 2>/dev/null || true
  xfconf-query -c xsettings -p /Net/IconThemeName -n -t string -s "Papirus-Dark" 2>/dev/null || true
  nexos-wallpaper-set /usr/share/backgrounds/nexos/nexos-green-matrix.png >/dev/null 2>&1 || true
  ;;
 purple)
  xfconf-query -c xsettings -p /Net/ThemeName -n -t string -s "Arc-Dark" 2>/dev/null || true
  xfconf-query -c xsettings -p /Net/IconThemeName -n -t string -s "Papirus-Dark" 2>/dev/null || true
  nexos-wallpaper-set /usr/share/backgrounds/nexos/nexos-purple-neon.png >/dev/null 2>&1 || true
  ;;
 classic)
  xfconf-query -c xsettings -p /Net/ThemeName -n -t string -s "Adwaita" 2>/dev/null || true
  xfconf-query -c xsettings -p /Net/IconThemeName -n -t string -s "hicolor" 2>/dev/null || true
  ;;
 *) echo "Usage: nexos-theme-apply dark|green|purple|classic"; exit 1;;
esac
notify-send "NexOS Personalization" "Theme applied: $profile" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-theme-apply
cat > /usr/local/bin/nexos-font-apply <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
font="${1:-Noto Sans 11}"
xfconf-query -c xsettings -p /Gtk/FontName -n -t string -s "$font" 2>/dev/null || true
xfconf-query -c xfwm4 -p /general/title_font -n -t string -s "$font" 2>/dev/null || true
notify-send "NexOS Personalization" "Font applied: $font" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-font-apply
cat > /usr/local/bin/nexos-layout-apply <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
layout="${1:-balanced}"
mkdir -p "$HOME/.config/nexos/personalization"
echo "$layout" > "$HOME/.config/nexos/personalization/layout"
case "$layout" in
 balanced)
  xfconf-query -c xfce4-panel -p /panels/panel-1/position -n -t string -s 'p=10;x=0;y=0' 2>/dev/null || true
  xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior -n -t int -s 0 2>/dev/null || true
  ;;
 clean)
  xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior -n -t int -s 1 2>/dev/null || true
  ;;
 desktop)
  xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior -n -t int -s 0 2>/dev/null || true
  ;;
 *) echo "Usage: nexos-layout-apply balanced|clean|desktop"; exit 1;;
esac
notify-send "NexOS Personalization" "Layout applied: $layout" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-layout-apply
cat > /usr/local/bin/nexos-personalization-report <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Reports/personalization-report-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$out")"
{
echo "NexOS Personalization Report"; echo "============================="; date; echo
echo "Theme settings:"; xfconf-query -c xsettings -l -v 2>/dev/null | grep -E 'Theme|Icon|Font' || true; echo
echo "Desktop settings:"; xfconf-query -c xfce4-desktop -l -v 2>/dev/null | grep -E 'last-image|image-style' || true; echo
echo "Panel settings:"; xfconf-query -c xfce4-panel -l -v 2>/dev/null | head -200 || true; echo
echo "Wallpapers:"; find /usr/share/backgrounds/nexos "$HOME/NexOS/Wallpapers" -type f 2>/dev/null | sort || true
} > "$out"
if command -v mousepad >/dev/null 2>&1; then mousepad "$out" >/dev/null 2>&1 & else xdg-open "$out" >/dev/null 2>&1 & fi
BASH
chmod 0755 /usr/local/bin/nexos-personalization-report
cat > /usr/local/bin/nexos-personalization-center <<'PY'
#!/usr/bin/env python3
import shutil, subprocess, tkinter as tk
from pathlib import Path
from tkinter import ttk, filedialog, messagebox
WALLS=[('/usr/share/backgrounds/nexos/nexos-dark-core.png','Dark Core'),('/usr/share/backgrounds/nexos/nexos-green-matrix.png','Green Matrix'),('/usr/share/backgrounds/nexos/nexos-purple-neon.png','Purple Neon'),('/usr/share/backgrounds/nexos/nexos-branding-v2.png','Branding v2')]
def run(c):
    e=c.split()[0]
    if shutil.which(e): subprocess.Popen(c.split(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    else: messagebox.showwarning('NexOS Personalization',f'{e} is not installed.')
def pick_wallpaper():
    f=filedialog.askopenfilename(initialdir=str(Path.home()/'NexOS/Wallpapers'),title='Choose wallpaper',filetypes=[('Images','*.png *.jpg *.jpeg *.webp'),('All files','*.*')])
    if f: run('nexos-wallpaper-set '+repr(f))
r=tk.Tk(); r.title('NexOS Personalization Center'); r.geometry('1040x700'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Personalization Center',bg='#07111f',fg='#e8f7ff',font=('Sans',31,'bold')).pack(anchor='w',padx=24,pady=(20,4))
tk.Label(r,text='Wallpapers, themes, icons, fonts, dock/panel layout, branding, and desktop style.',bg='#07111f',fg='#9bd5ff',wraplength=920,justify='left').pack(anchor='w',padx=24,pady=(0,10))
nb=ttk.Notebook(r); nb.pack(fill='both',expand=True,padx=18,pady=14)
wall=tk.Frame(nb,bg='#07111f',padx=14,pady=14); nb.add(wall,text='Wallpapers')
for i,(path,name) in enumerate(WALLS): tk.Button(wall,text=name,command=lambda p=path:run('nexos-wallpaper-set '+p),bg='#1f2937',fg='#e8f7ff',activebackground='#0ea5e9',relief='flat',padx=14,pady=14,font=('Sans',12,'bold')).grid(row=i//2,column=i%2,padx=8,pady=8,sticky='ew'); wall.grid_columnconfigure(i%2,weight=1)
tk.Button(wall,text='Choose Custom Wallpaper',command=pick_wallpaper,bg='#0ea5e9',fg='white',relief='flat',padx=14,pady=14,font=('Sans',12,'bold')).grid(row=3,column=0,columnspan=2,padx=8,pady=16,sticky='ew')
theme=tk.Frame(nb,bg='#07111f',padx=14,pady=14); nb.add(theme,text='Themes')
for i,(n,p) in enumerate([('NexOS Dark','dark'),('NexOS Green','green'),('NexOS Purple','purple'),('Classic','classic')]): tk.Button(theme,text=n,command=lambda x=p:run('nexos-theme-apply '+x),bg='#1f2937',fg='#e8f7ff',activebackground='#0ea5e9',relief='flat',padx=14,pady=14,font=('Sans',12,'bold')).grid(row=i//2,column=i%2,padx=8,pady=8,sticky='ew'); theme.grid_columnconfigure(i%2,weight=1)
layout=tk.Frame(nb,bg='#07111f',padx=14,pady=14); nb.add(layout,text='Layout')
for i,(n,p) in enumerate([('Balanced Layout','balanced'),('Clean Autohide Layout','clean'),('Desktop Layout','desktop')]): tk.Button(layout,text=n,command=lambda x=p:run('nexos-layout-apply '+x),bg='#1f2937',fg='#e8f7ff',activebackground='#0ea5e9',relief='flat',padx=14,pady=14,font=('Sans',12,'bold')).grid(row=i//2,column=i%2,padx=8,pady=8,sticky='ew'); layout.grid_columnconfigure(i%2,weight=1)
fonts=tk.Frame(nb,bg='#07111f',padx=14,pady=14); nb.add(fonts,text='Fonts')
for i,f in enumerate(['Noto Sans 11','DejaVu Sans 11','Liberation Sans 11','Sans 12']): tk.Button(fonts,text=f,command=lambda x=f:run('nexos-font-apply '+repr(x)),bg='#1f2937',fg='#e8f7ff',relief='flat',padx=14,pady=14,font=('Sans',12,'bold')).grid(row=i//2,column=i%2,padx=8,pady=8,sticky='ew'); fonts.grid_columnconfigure(i%2,weight=1)
tools=tk.Frame(nb,bg='#07111f',padx=14,pady=14); nb.add(tools,text='Tools')
for i,(n,c) in enumerate([('Branding Center','nexos-branding-center'),('Theme Center','nexos-theme-center'),('Appearance Settings','xfce4-appearance-settings'),('Window Manager','xfwm4-settings'),('Settings','nexos-settings'),('Report','nexos-personalization-report')]): tk.Button(tools,text=n,command=lambda x=c:run(x),bg='#1f2937',fg='#e8f7ff',activebackground='#0ea5e9',relief='flat',padx=14,pady=14,font=('Sans',11,'bold')).grid(row=i//2,column=i%2,padx=8,pady=8,sticky='ew'); tools.grid_columnconfigure(i%2,weight=1)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-personalization-center
for spec in "nexos-personalization-center|NexOS Personalization Center|Settings;DesktopSettings;" "nexos-personalization-report|NexOS Personalization Report|Settings;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-personalization.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-personalization-center' not in s: p.write_text(s.replace('\n]', '\n    ("Personalize", ["nexos-personalization-center"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /usr/local/bin/nexos-action-center ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-action-center'); s=p.read_text()
if "('Personalize','nexos-personalization-center')" not in s:
    s=s.replace("('Settings','nexos-settings')", "('Personalize','nexos-personalization-center'),('Settings','nexos-settings')")
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-action-center; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('personalization center','nexos-personalization-center','NexOS Personalization Center'),('personalize','nexos-personalization-center','NexOS Personalization Center'),('dark theme','nexos-theme-apply dark','Apply NexOS Dark Theme'),('green theme','nexos-theme-apply green','Apply NexOS Green Theme'),('purple theme','nexos-theme-apply purple','Apply NexOS Purple Theme')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Personalization Center:
- Adds wallpapers, theme profiles, font helper, layout helper, personalization reports, dock/menu entries, Action Center integration, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/420-nexos-personalization-center.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/420-nexos-personalization-center.hook.chroot"
success "Injected NexOS Personalization Center for $NEXOS_EDITION."
