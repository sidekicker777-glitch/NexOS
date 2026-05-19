#!/usr/bin/env bash
# NexOS Software Center: category app installer/remove hub.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/72-nexos-software-center.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
curl
wget
ca-certificates
gnupg
flatpak
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/310-nexos-software-center.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin curl wget ca-certificates gnupg flatpak; do install_if_available "$p"; done
mkdir -p /opt/nexos/software-center "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/NexOS/Reports" "$home_dir/.config/nexos/software-center"
cat > "$icon_dir/nexos-software-center.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#22c55e" stroke-width="4"/><path d="M36 45h56l-5 49H41z" fill="none" stroke="#38bdf8" stroke-width="7" stroke-linejoin="round"/><path d="M48 45c0-17 32-17 32 0" fill="none" stroke="#e8f7ff" stroke-width="7" stroke-linecap="round"/><path d="M51 69h26M64 56v26" stroke="#22c55e" stroke-width="7" stroke-linecap="round"/></svg>
SVG
cat > /opt/nexos/software-center/catalog.json <<'JSON'
{"Development":["geany","kate","codeblocks","sqlitebrowser","gitg","meld"],"Media":["vlc","gimp","inkscape","krita","audacity","kdenlive","obs-studio"],"Gaming":["retroarch","dolphin-emu","pcsx2","ppsspp","mame","dosbox","lutris"],"Internet":["firefox-esr","chromium","thunderbird","transmission-gtk","filezilla","remmina"],"System":["gparted","baobab","bleachbit","synaptic","timeshift","pavucontrol","arandr"],"Creative":["blender","freecad","openscad","librecad","godot3","lmms"]}
JSON
cat > /usr/local/bin/nexos-software-report <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Reports/software-report-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$out")"
{
echo "NexOS Software Report"; date; echo
apt list --upgradable 2>/dev/null || true; echo
flatpak list 2>/dev/null || true; echo
ls /usr/local/bin/nexos-* 2>/dev/null || true
} > "$out"
if command -v mousepad >/dev/null 2>&1; then mousepad "$out" >/dev/null 2>&1 & else xdg-open "$out" >/dev/null 2>&1 & fi
BASH
chmod 0755 /usr/local/bin/nexos-software-report
cat > /usr/local/bin/nexos-install-app <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
pkg="${1:-}"; [[ -n "$pkg" ]] || { echo "Usage: nexos-install-app <package>"; exit 1; }
sudo apt-get update && sudo apt-get install -y "$pkg"
notify-send "NexOS Software Center" "Install finished: $pkg" 2>/dev/null || true
echo; echo "Press Enter to close"; read -r _ || true
BASH
chmod 0755 /usr/local/bin/nexos-install-app
cat > /usr/local/bin/nexos-remove-app <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
pkg="${1:-}"; [[ -n "$pkg" ]] || { echo "Usage: nexos-remove-app <package>"; exit 1; }
sudo apt-get remove -y "$pkg"
notify-send "NexOS Software Center" "Remove finished: $pkg" 2>/dev/null || true
echo; echo "Press Enter to close"; read -r _ || true
BASH
chmod 0755 /usr/local/bin/nexos-remove-app
cat > /usr/local/bin/nexos-software-center <<'PY'
#!/usr/bin/env python3
import json, shutil, subprocess, tkinter as tk
from pathlib import Path
from tkinter import ttk, messagebox
CAT=Path('/opt/nexos/software-center/catalog.json')
DATA=json.loads(CAT.read_text()) if CAT.exists() else {'System':['synaptic']}
def installed(p): return subprocess.call(['dpkg','-s',p],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)==0
def term(cmd):
    t=shutil.which('xfce4-terminal') or shutil.which('x-terminal-emulator')
    if t: subprocess.Popen([t,'-e','bash','-lc',cmd],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
def open_tool(c):
    e=c.split()[0]
    if shutil.which(e): subprocess.Popen(c.split(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    else: messagebox.showwarning('NexOS Software Center',f'{e} is not installed.')
r=tk.Tk(); r.title('NexOS Software Center'); r.geometry('1060x690'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Software Center',bg='#07111f',fg='#e8f7ff',font=('Sans',32,'bold')).pack(anchor='w',padx=24,pady=(20,4))
tk.Label(r,text='Install and remove optional open-source apps from configured repositories.',bg='#07111f',fg='#9bd5ff').pack(anchor='w',padx=24,pady=(0,12))
bar=tk.Frame(r,bg='#07111f'); bar.pack(fill='x',padx=20)
for n,c in [('Update Center','nexos-update-center'),('Software Report','nexos-software-report'),('Synaptic','synaptic'),('Control Suite','nexos-control-suite')]: tk.Button(bar,text=n,command=lambda x=c:open_tool(x),bg='#111827',fg='#e8f7ff',relief='flat',padx=12,pady=8).pack(side='left',padx=4)
nb=ttk.Notebook(r); nb.pack(fill='both',expand=True,padx=18,pady=14)
for cat,apps in DATA.items():
    f=tk.Frame(nb,bg='#07111f',padx=14,pady=14); nb.add(f,text=cat)
    for i,pkg in enumerate(apps):
        card=tk.Frame(f,bg='#0d172b',padx=12,pady=10,highlightbackground='#294866',highlightthickness=1); card.grid(row=i//3,column=i%3,padx=8,pady=8,sticky='nsew'); f.grid_columnconfigure(i%3,weight=1)
        ok=installed(pkg); tk.Label(card,text=pkg,bg='#0d172b',fg='#e8f7ff',font=('Sans',13,'bold')).pack(anchor='w'); tk.Label(card,text='Installed' if ok else 'Not installed',bg='#0d172b',fg='#86efac' if ok else '#fbbf24').pack(anchor='w',pady=(2,8))
        row=tk.Frame(card,bg='#0d172b'); row.pack(fill='x')
        tk.Button(row,text='Install',command=lambda p=pkg:term(f'nexos-install-app {p}'),bg='#16a34a',fg='white',relief='flat').pack(side='left')
        tk.Button(row,text='Remove',command=lambda p=pkg:term(f'nexos-remove-app {p}'),bg='#7f1d1d',fg='white',relief='flat').pack(side='right')
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-software-center
for spec in "nexos-software-center|NexOS Software Center|System;Settings;PackageManager;" "nexos-software-report|NexOS Software Report|System;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-software-center.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-software-center' not in s: p.write_text(s.replace('\n]', '\n    ("Store", ["nexos-software-center"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('software center','nexos-software-center','NexOS Software Center'),('app store','nexos-software-center','NexOS Software Center'),('software report','nexos-software-report','NexOS Software Report')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Software Center:
- Adds category app store/software center with install/remove actions, software report, catalog, dock/menu entries, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/310-nexos-software-center.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/310-nexos-software-center.hook.chroot"
success "Injected NexOS Software Center for $NEXOS_EDITION."
