#!/usr/bin/env bash
# NexOS Install Center v2: install guidance, disk checks, post-install setup, first boot helpers.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/71-nexos-install-center-v2.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
parted
rsync
util-linux
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/300-nexos-install-center-v2.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin parted gparted calamares calamares-settings-debian rsync util-linux os-prober efibootmgr; do install_if_available "$p"; done
# Do not install both grub-pc and grub-efi-amd64 in the live image. They conflict.
# Calamares/install tooling should select the correct bootloader for the target machine during install.
mkdir -p /opt/nexos/install-center "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/NexOS/Reports" "$home_dir/.config/nexos/install-center"
cat > "$icon_dir/nexos-install-center.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#22c55e" stroke-width="4"/><path d="M64 27v45M44 53l20 20 20-20" fill="none" stroke="#e8f7ff" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/><rect x="34" y="86" width="60" height="16" rx="6" fill="none" stroke="#38bdf8" stroke-width="7"/></svg>
SVG
cat > /usr/local/bin/nexos-install-report <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Reports/install-report-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$out")"
{
echo "NexOS Install Readiness Report"; echo "==============================="; date; echo
echo "Boot mode:"; if [[ -d /sys/firmware/efi ]]; then echo UEFI; else echo Legacy BIOS; fi; echo
echo "Disks:"; lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL 2>/dev/null || true; echo
echo "Partitions:"; sudo parted -l 2>/dev/null || true; echo
echo "Memory:"; free -h 2>/dev/null || true; echo
echo "CPU:"; lscpu 2>/dev/null | head -40 || true; echo
echo "Installer availability:"; command -v calamares || true; command -v gparted || true; command -v grub-install || true
} > "$out"
if command -v mousepad >/dev/null 2>&1; then mousepad "$out" >/dev/null 2>&1 & else xdg-open "$out" >/dev/null 2>&1 & fi
BASH
chmod 0755 /usr/local/bin/nexos-install-report
cat > /usr/local/bin/nexos-post-install-setup <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/.config/nexos/first-run" "$HOME/NexOS/Projects" "$HOME/NexOS/Notes" "$HOME/NexOS/Reports" "$HOME/Games/NexOS/ROMs" "$HOME/Games/NexOS/BIOS" "$HOME/Games/NexOS/Saves"
nexos-desktop-finalize >/dev/null 2>&1 || true
nexos-display-fix >/dev/null 2>&1 || true
nexos-trust-launchers >/dev/null 2>&1 || true
notify-send "NexOS" "Post-install setup applied" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-post-install-setup
cat > /usr/local/bin/nexos-install-center <<'PY'
#!/usr/bin/env python3
import shutil, subprocess, tkinter as tk
from tkinter import ttk, messagebox
A={
'Install':[('Launch Calamares Installer','calamares'),('Install Readiness Report','nexos-install-report'),('Open GParted','gparted')],
'Pre-checks':[('Show Disks','x-terminal-emulator -e lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL'),('Boot Mode Check','x-terminal-emulator -e bash -lc "if [ -d /sys/firmware/efi ]; then echo UEFI; else echo Legacy BIOS; fi; echo; read"'),('Memory Check','x-terminal-emulator -e free -h')],
'After Install':[('Run Post-Install Setup','nexos-post-install-setup'),('Open First-Run Wizard','nexos-first-run-wizard'),('Open Settings','nexos-settings'),('Open Update Center','nexos-update-center')],
'Help':[('Open Install Report Folder','xdg-open ~/NexOS/Reports'),('Open Driver Center','nexos-driver-center'),('Open Control Suite','nexos-control-suite')]
}
def run(c):
    e=c.split()[0]
    if shutil.which(e): subprocess.Popen(c.split(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    else: messagebox.showwarning('NexOS Install Center',f'{e} is not installed in this build. It may be moved to optional install if unavailable in the repo.')
r=tk.Tk(); r.title('NexOS Install Center'); r.geometry('980x650'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Install Center',bg='#07111f',fg='#e8f7ff',font=('Sans',30,'bold')).pack(anchor='w',padx=24,pady=(20,4))
tk.Label(r,text='Install NexOS, check disks, prepare boot mode, and run post-install setup.',bg='#07111f',fg='#9bd5ff',font=('Sans',12)).pack(anchor='w',padx=24,pady=(0,12))
nb=ttk.Notebook(r); nb.pack(fill='both',expand=True,padx=18,pady=14)
for cat,items in A.items():
    f=tk.Frame(nb,bg='#07111f',padx=14,pady=14); nb.add(f,text=cat)
    for i,(n,c) in enumerate(items): tk.Button(f,text=n,command=lambda x=c:run(x),bg='#1f2937',fg='#e8f7ff',activebackground='#0ea5e9',relief='flat',padx=14,pady=14,font=('Sans',11,'bold')).grid(row=i//2,column=i%2,padx=8,pady=8,sticky='ew'); f.grid_columnconfigure(i%2,weight=1)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-install-center
for spec in "nexos-install-center|NexOS Install Center|System;Settings;" "nexos-install-report|NexOS Install Report|System;" "nexos-post-install-setup|NexOS Post-Install Setup|System;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-install-center.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-install-center' not in s: p.write_text(s.replace('\n]', '\n    ("Install", ["nexos-install-center"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('install center','nexos-install-center','NexOS Install Center'),('install report','nexos-install-report','NexOS Install Report'),('post install setup','nexos-post-install-setup','NexOS Post-Install Setup')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Install Center v2:
- Adds installer hub, disk/boot readiness report, GParted/Calamares launchers, post-install setup, dock/menu entries, and assistant catalog entries.
- Keeps conflicting bootloader packages out of hard package lists so the live ISO can build; installer tooling picks BIOS/UEFI bootloader at install time.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/300-nexos-install-center-v2.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/300-nexos-install-center-v2.hook.chroot"
success "Injected NexOS Install Center v2 for $NEXOS_EDITION."
