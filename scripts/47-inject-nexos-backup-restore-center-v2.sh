#!/usr/bin/env bash
# NexOS Backup / Restore Center v2: home/settings/NexOS config/game saves backup and restore helpers.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/80-nexos-backup-restore-center.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
rsync
tar
gzip
xz-utils
zip
unzip
coreutils
findutils
util-linux
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/390-nexos-backup-restore-center.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin rsync tar gzip xz-utils zip unzip coreutils findutils util-linux; do install_if_available "$p"; done
mkdir -p /opt/nexos/backup-restore-center "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/NexOS/Backups" "$home_dir/NexOS/Restore-Staging" "$home_dir/NexOS/Reports" "$home_dir/.config/nexos/backup-restore"
cat > "$icon_dir/nexos-backup-restore.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><path d="M35 47h58a8 8 0 0 1 8 8v38a8 8 0 0 1-8 8H35a8 8 0 0 1-8-8V55a8 8 0 0 1 8-8z" fill="none" stroke="#e8f7ff" stroke-width="7"/><path d="M44 47c4-17 36-17 40 0" fill="none" stroke="#22c55e" stroke-width="7" stroke-linecap="round"/><path d="M64 83V61M52 73l12-12 12 12" fill="none" stroke="#38bdf8" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/></svg>
SVG
cat > /usr/local/bin/nexos-backup-home <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
base="$HOME/NexOS/Backups"
mkdir -p "$base"
out="$base/home-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
tar --exclude="$HOME/NexOS/Backups" --exclude="$HOME/.cache" --exclude="$HOME/.local/share/Trash" -czf "$out" -C "$HOME" .
notify-send "NexOS Backup" "Home backup created" 2>/dev/null || true
echo "$out"
BASH
chmod 0755 /usr/local/bin/nexos-backup-home
cat > /usr/local/bin/nexos-backup-configs <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
base="$HOME/NexOS/Backups"
mkdir -p "$base"
out="$base/config-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
tmp="$(mktemp -d)"
mkdir -p "$tmp/config"
for p in "$HOME/.config/nexos" "$HOME/.config/autostart" "$HOME/.local/share/applications" "$HOME/.bashrc" "$HOME/.profile"; do
  [[ -e "$p" ]] && rsync -a "$p" "$tmp/config/" 2>/dev/null || true
done
tar -czf "$out" -C "$tmp" config
rm -rf "$tmp"
notify-send "NexOS Backup" "Config backup created" 2>/dev/null || true
echo "$out"
BASH
chmod 0755 /usr/local/bin/nexos-backup-configs
cat > /usr/local/bin/nexos-backup-nexos-data <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
base="$HOME/NexOS/Backups"
mkdir -p "$base"
out="$base/nexos-data-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
tar --exclude="$HOME/NexOS/Backups" -czf "$out" -C "$HOME" NexOS 2>/dev/null || true
notify-send "NexOS Backup" "NexOS data backup created" 2>/dev/null || true
echo "$out"
BASH
chmod 0755 /usr/local/bin/nexos-backup-nexos-data
cat > /usr/local/bin/nexos-backup-game-saves <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
base="$HOME/NexOS/Backups"
mkdir -p "$base"
out="$base/game-saves-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
tmp="$(mktemp -d)"
mkdir -p "$tmp/game-saves"
for p in "$HOME/Games/NexOS/Saves" "$HOME/.config/retroarch/saves" "$HOME/.config/retroarch/states" "$HOME/.local/share/dolphin-emu" "$HOME/.config/PCSX2"; do
  [[ -e "$p" ]] && rsync -a "$p" "$tmp/game-saves/" 2>/dev/null || true
done
tar -czf "$out" -C "$tmp" game-saves
rm -rf "$tmp"
notify-send "NexOS Backup" "Game saves backup created" 2>/dev/null || true
echo "$out"
BASH
chmod 0755 /usr/local/bin/nexos-backup-game-saves
cat > /usr/local/bin/nexos-restore-backup <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
archive="${1:-}"
[[ -f "$archive" ]] || { echo "Usage: nexos-restore-backup <backup.tar.gz> [destination]"; exit 1; }
dest="${2:-$HOME/NexOS/Restore-Staging/$(basename "$archive")-restored}"
mkdir -p "$dest"
tar -xzf "$archive" -C "$dest"
notify-send "NexOS Restore" "Backup extracted to staging" 2>/dev/null || true
xdg-open "$dest" >/dev/null 2>&1 &
BASH
chmod 0755 /usr/local/bin/nexos-restore-backup
cat > /usr/local/bin/nexos-backup-report <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Reports/backup-report-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$out")"
{
echo "NexOS Backup / Restore Report"; echo "=============================="; date; echo
echo "Backup folder:"; du -sh "$HOME/NexOS/Backups" 2>/dev/null || true; echo
echo "Backups:"; find "$HOME/NexOS/Backups" -maxdepth 1 -type f -printf '%TY-%Tm-%Td %TH:%TM  %s  %p\n' 2>/dev/null | sort -r || true; echo
echo "Restore staging:"; du -sh "$HOME/NexOS/Restore-Staging" 2>/dev/null || true; echo
echo "Disk space:"; df -h "$HOME" 2>/dev/null || true; echo
echo "NexOS data folders:"; du -h -d 1 "$HOME/NexOS" 2>/dev/null | sort -hr || true
} > "$out"
if command -v mousepad >/dev/null 2>&1; then mousepad "$out" >/dev/null 2>&1 & else xdg-open "$out" >/dev/null 2>&1 & fi
BASH
chmod 0755 /usr/local/bin/nexos-backup-report
cat > /usr/local/bin/nexos-backup-restore-center <<'PY'
#!/usr/bin/env python3
import shutil, subprocess, tkinter as tk
from pathlib import Path
from tkinter import ttk, filedialog, messagebox
HOME=Path.home(); BACK=HOME/'NexOS/Backups'; STAGE=HOME/'NexOS/Restore-Staging'; BACK.mkdir(parents=True,exist_ok=True); STAGE.mkdir(parents=True,exist_ok=True)
def run(c):
    e=c[0] if isinstance(c,list) else c.split()[0]
    if shutil.which(e): subprocess.Popen(c if isinstance(c,list) else c.split(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    else: messagebox.showwarning('NexOS Backup Center',f'{e} is not installed.')
def term(cmd):
    t=shutil.which('xfce4-terminal') or shutil.which('x-terminal-emulator')
    if t: subprocess.Popen([t,'-e','bash','-lc',cmd],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    else: run(cmd)
def pick_restore():
    f=filedialog.askopenfilename(initialdir=str(BACK),title='Choose backup archive',filetypes=[('Backup archives','*.tar.gz *.tgz'),('All files','*.*')])
    if f: term('nexos-restore-backup '+repr(f))
def refresh():
    tree.delete(*tree.get_children())
    for p in sorted(BACK.glob('*'),key=lambda x:x.stat().st_mtime if x.exists() else 0,reverse=True):
        size=p.stat().st_size/1024/1024
        tree.insert('', 'end', values=(p.name,f'{size:.1f} MB',str(p)))
r=tk.Tk(); r.title('NexOS Backup / Restore Center'); r.geometry('980x670'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Backup / Restore Center',bg='#07111f',fg='#e8f7ff',font=('Sans',29,'bold')).pack(anchor='w',padx=24,pady=(20,4))
tk.Label(r,text='Back up home data, NexOS config, app settings, and game saves. Restore archives into safe staging folders first.',bg='#07111f',fg='#9bd5ff',wraplength=880,justify='left').pack(anchor='w',padx=24,pady=(0,12))
nb=ttk.Notebook(r); nb.pack(fill='both',expand=True,padx=18,pady=14)
backup=tk.Frame(nb,bg='#07111f',padx=14,pady=14); nb.add(backup,text='Backup')
for n,c in [('Back Up Home Folder','nexos-backup-home'),('Back Up NexOS Configs','nexos-backup-configs'),('Back Up NexOS Data','nexos-backup-nexos-data'),('Back Up Game Saves','nexos-backup-game-saves')]: tk.Button(backup,text=n,command=lambda x=c:term(x),bg='#1f2937',fg='#e8f7ff',activebackground='#0ea5e9',relief='flat',padx=16,pady=14,font=('Sans',11,'bold')).pack(fill='x',pady=7)
restore=tk.Frame(nb,bg='#07111f',padx=14,pady=14); nb.add(restore,text='Restore')
tk.Button(restore,text='Choose Backup To Restore Into Staging',command=pick_restore,bg='#0ea5e9',fg='white',relief='flat',padx=16,pady=14,font=('Sans',12,'bold')).pack(fill='x',pady=7)
tk.Button(restore,text='Open Restore Staging Folder',command=lambda:run(['xdg-open',str(STAGE)]),bg='#1f2937',fg='#e8f7ff',relief='flat',padx=16,pady=14).pack(fill='x',pady=7)
manage=tk.Frame(nb,bg='#07111f',padx=14,pady=14); nb.add(manage,text='Manage')
cols=('Name','Size','Path'); tree=ttk.Treeview(manage,columns=cols,show='headings')
for c in cols: tree.heading(c,text=c); tree.column(c,width=260 if c!='Size' else 90)
tree.pack(fill='both',expand=True,pady=8)
bar=tk.Frame(manage,bg='#07111f'); bar.pack(fill='x')
for n,c in [('Refresh',refresh),('Open Backups',lambda:run(['xdg-open',str(BACK)])),('Backup Report',lambda:run('nexos-backup-report')),('File Center',lambda:run('nexos-file-center'))]: tk.Button(bar,text=n,command=c,bg='#1f2937',fg='#e8f7ff',relief='flat',padx=12,pady=10).pack(side='left',padx=4)
refresh(); r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-backup-restore-center
for spec in "nexos-backup-restore-center|NexOS Backup Restore Center|System;Utility;" "nexos-backup-report|NexOS Backup Report|System;Utility;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-backup-restore.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-backup-restore-center' not in s: p.write_text(s.replace('\n]', '\n    ("Backup", ["nexos-backup-restore-center"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /usr/local/bin/nexos-action-center ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-action-center'); s=p.read_text()
if "('Backup','nexos-backup-restore-center')" not in s:
    s=s.replace("('Files','nexos-file-center')", "('Files','nexos-file-center'),('Backup','nexos-backup-restore-center')")
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-action-center; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('backup center','nexos-backup-restore-center','NexOS Backup Restore Center'),('backup home','x-terminal-emulator -e nexos-backup-home','Back Up Home'),('backup configs','x-terminal-emulator -e nexos-backup-configs','Back Up Configs'),('backup game saves','x-terminal-emulator -e nexos-backup-game-saves','Back Up Game Saves'),('backup report','nexos-backup-report','NexOS Backup Report')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Backup / Restore Center v2:
- Adds home backup, config backup, NexOS data backup, game saves backup, staged restore, reports, dock/menu entries, Action Center integration, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/390-nexos-backup-restore-center.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/390-nexos-backup-restore-center.hook.chroot"
success "Injected NexOS Backup / Restore Center v2 for $NEXOS_EDITION."
