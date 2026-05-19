#!/usr/bin/env bash
# NexOS Update Center: safe update/repair/cache/report hub for installed/live sessions.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/65-nexos-update-center.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
curl
wget
aptitude
apt-listchanges
apt-transport-https
ca-certificates
gnupg
software-properties-common
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/240-nexos-update-center.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin curl wget aptitude apt-listchanges apt-transport-https ca-certificates gnupg software-properties-common; do install_if_available "$p"; done
mkdir -p /opt/nexos/update-center "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/NexOS/Reports" "$home_dir/.config/nexos/update-center"
cat > "$icon_dir/nexos-update-center.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#22c55e" stroke-width="4"/><path d="M64 31v47M44 58l20 20 20-20" fill="none" stroke="#e8f7ff" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/><path d="M37 94h54" stroke="#38bdf8" stroke-width="8" stroke-linecap="round"/></svg>
SVG
cat > /usr/local/bin/nexos-update-report <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Reports/update-report-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$out")"
{
echo "NexOS Update Report"; echo "==================="; date; echo
echo "APT sources:"; find /etc/apt -name '*.list' -o -name '*.sources' 2>/dev/null | while read -r f; do echo "--- $f"; sed -n '1,120p' "$f"; done; echo
echo "Upgradeable packages:"; apt list --upgradable 2>/dev/null || true; echo
echo "Held packages:"; apt-mark showhold 2>/dev/null || true; echo
echo "Broken check:"; apt-get check 2>&1 || true
} > "$out"
if command -v mousepad >/dev/null 2>&1; then mousepad "$out" >/dev/null 2>&1 & else xdg-open "$out" >/dev/null 2>&1 & fi
BASH
chmod 0755 /usr/local/bin/nexos-update-report
cat > /usr/local/bin/nexos-update-check <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
sudo apt-get update
apt list --upgradable 2>/dev/null || true
echo; echo "Press Enter to close"; read -r _ || true
BASH
chmod 0755 /usr/local/bin/nexos-update-check
cat > /usr/local/bin/nexos-update-system <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get autoremove -y
notify-send "NexOS Update Center" "System update completed" 2>/dev/null || true
echo; echo "Press Enter to close"; read -r _ || true
BASH
chmod 0755 /usr/local/bin/nexos-update-system
cat > /usr/local/bin/nexos-repair-packages <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
sudo dpkg --configure -a
sudo apt-get install -f -y
sudo apt-get check
echo; echo "Press Enter to close"; read -r _ || true
BASH
chmod 0755 /usr/local/bin/nexos-repair-packages
cat > /usr/local/bin/nexos-clean-packages <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
sudo apt-get autoremove -y
sudo apt-get autoclean -y
sudo apt-get clean
notify-send "NexOS Update Center" "Package cache cleaned" 2>/dev/null || true
echo; echo "Press Enter to close"; read -r _ || true
BASH
chmod 0755 /usr/local/bin/nexos-clean-packages
cat > /usr/local/bin/nexos-update-center <<'PY'
#!/usr/bin/env python3
import shutil, subprocess, tkinter as tk
from tkinter import ttk, messagebox
A={'Updates':[('Check Updates','x-terminal-emulator -e nexos-update-check'),('Update System','x-terminal-emulator -e nexos-update-system'),('Update Report','nexos-update-report')],'Repair':[('Repair Packages','x-terminal-emulator -e nexos-repair-packages'),('Clean Package Cache','x-terminal-emulator -e nexos-clean-packages'),('Control Suite','nexos-control-suite')],'Info':[('APT Sources Report','nexos-update-report'),('Open Reports','xdg-open ~/NexOS/Reports'),('App Installer','nexos-app-installer')]}
def run(c):
    e=c.split()[0]
    if shutil.which(e): subprocess.Popen(c.split(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    else: messagebox.showwarning('NexOS Update Center',f'{e} is not installed.')
r=tk.Tk(); r.title('NexOS Update Center'); r.geometry('920x610'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Update Center',bg='#07111f',fg='#e8f7ff',font=('Sans',30,'bold')).pack(anchor='w',padx=24,pady=18)
nb=ttk.Notebook(r); nb.pack(fill='both',expand=True,padx=18,pady=14)
for cat,items in A.items():
    f=tk.Frame(nb,bg='#07111f',padx=14,pady=14); nb.add(f,text=cat)
    for i,(n,c) in enumerate(items): tk.Button(f,text=n,command=lambda x=c:run(x),bg='#1f2937',fg='#e8f7ff',activebackground='#0ea5e9',relief='flat',padx=14,pady=14,font=('Sans',11,'bold')).grid(row=i//2,column=i%2,padx=8,pady=8,sticky='ew'); f.grid_columnconfigure(i%2,weight=1)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-update-center
for spec in "nexos-update-center|NexOS Update Center|System;Settings;" "nexos-update-report|NexOS Update Report|System;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-update-center.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-update-center' not in s: p.write_text(s.replace('\n]', '\n    ("Update", ["nexos-update-center"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('update center','nexos-update-center','NexOS Update Center'),('update report','nexos-update-report','NexOS Update Report'),('check updates','x-terminal-emulator -e nexos-update-check','NexOS Check Updates')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Update Center:
- Adds update checking, system upgrade launcher, package repair, package cleanup, update reports, dock/menu entries, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/240-nexos-update-center.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/240-nexos-update-center.hook.chroot"
success "Injected NexOS Update Center for $NEXOS_EDITION."
