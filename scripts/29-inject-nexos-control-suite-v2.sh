#!/usr/bin/env bash
# NexOS Control Suite v2: broad OS hub for settings, apps, repair, backup, reports, themes.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/62-nexos-control-suite-v2.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
rsync
curl
wget
pciutils
usbutils
procps
iproute2
network-manager
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/210-nexos-control-suite-v2.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin rsync curl wget pciutils usbutils procps iproute2 network-manager baobab gparted timeshift bleachbit synaptic flatpak; do install_if_available "$p"; done
mkdir -p /opt/nexos/control-suite-v2 "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/NexOS/Backups" "$home_dir/NexOS/Reports"
cat > "$icon_dir/nexos-control-suite.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><circle cx="64" cy="64" r="31" fill="none" stroke="#22c55e" stroke-width="8"/><circle cx="64" cy="64" r="10" fill="#e8f7ff"/><path d="M64 24v15M64 89v15M24 64h15M89 64h15" stroke="#e8f7ff" stroke-width="6" stroke-linecap="round"/></svg>
SVG
cat > /usr/local/bin/nexos-full-system-report <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Reports/system-report-$(date +%Y%m%d-%H%M%S).txt"; mkdir -p "$(dirname "$out")"
{ echo "NexOS Full System Report"; date; cat /etc/os-release 2>/dev/null || true; uname -a; lscpu 2>/dev/null || true; free -h 2>/dev/null || true; df -h 2>/dev/null || true; lsblk 2>/dev/null || true; ip addr 2>/dev/null || true; lspci 2>/dev/null || true; lsusb 2>/dev/null || true; } > "$out"
if command -v mousepad >/dev/null 2>&1; then mousepad "$out" >/dev/null 2>&1 & else xdg-open "$out" >/dev/null 2>&1 & fi
BASH
chmod 0755 /usr/local/bin/nexos-full-system-report
cat > /usr/local/bin/nexos-backup-home <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
dest="$HOME/NexOS/Backups/home-backup-$(date +%Y%m%d-%H%M%S)"; mkdir -p "$dest"; rsync -a --exclude='.cache' --exclude='NexOS/Backups' "$HOME/" "$dest/"; notify-send "NexOS Backup" "Home backup complete" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-backup-home
cat > /usr/local/bin/nexos-control-suite <<'PY'
#!/usr/bin/env python3
import shutil, subprocess, tkinter as tk
from tkinter import ttk, messagebox
TOOLS={'Settings':[('XFCE Settings','xfce4-settings-manager'),('Display','xfce4-display-settings'),('Network','nm-connection-editor')],'Apps':[('Synaptic','synaptic'),('Flatpak Info','x-terminal-emulator -e flatpak --version')],'Repair':[('Fix Desktop','nexos-desktop-finalize'),('Fix Display','nexos-display-fix'),('Trust Launchers','nexos-trust-launchers'),('System Report','nexos-full-system-report'),('Backup Home','x-terminal-emulator -e nexos-backup-home')],'Storage':[('Disk Usage','baobab'),('GParted','gparted'),('Files','thunar')]}
def run(c):
    e=c.split()[0]
    if shutil.which(e): subprocess.Popen(c.split(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else: messagebox.showwarning('NexOS',f'{e} is not installed in this build.')
r=tk.Tk(); r.title('NexOS Control Suite'); r.geometry('980x650'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Control Suite',bg='#07111f',fg='#e8f7ff',font=('Sans',30,'bold')).pack(anchor='w',padx=24,pady=18)
nb=ttk.Notebook(r); nb.pack(fill='both',expand=True,padx=18,pady=14)
for cat,items in TOOLS.items():
    f=tk.Frame(nb,bg='#07111f',padx=14,pady=14); nb.add(f,text=cat)
    for i,(n,c) in enumerate(items): tk.Button(f,text=n,command=lambda x=c:run(x),bg='#1f2937',fg='#e8f7ff',relief='flat',padx=14,pady=14,font=('Sans',11,'bold')).grid(row=i//2,column=i%2,padx=8,pady=8,sticky='ew'); f.grid_columnconfigure(i%2,weight=1)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-control-suite
cat > /usr/local/bin/nexos-repair-center <<'BASH'
#!/usr/bin/env bash
nexos-control-suite
BASH
chmod 0755 /usr/local/bin/nexos-repair-center
for spec in "nexos-control-suite|NexOS Control Suite|System;Settings;" "nexos-full-system-report|NexOS Full System Report|System;" "nexos-repair-center|NexOS Repair Center|System;Settings;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-control-suite.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-control-suite' not in s: p.write_text(s.replace('\n]', '\n    ("Suite", ["nexos-control-suite"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('control suite','nexos-control-suite','NexOS Control Suite'),('repair center','nexos-repair-center','NexOS Repair Center'),('system report','nexos-full-system-report','NexOS Full System Report')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Control Suite v2:
- Adds broad settings/apps/repair/storage/report/backup hub.
- Adds full system report and home backup helper.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/210-nexos-control-suite-v2.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/210-nexos-control-suite-v2.hook.chroot"
success "Injected NexOS Control Suite v2 for $NEXOS_EDITION."
