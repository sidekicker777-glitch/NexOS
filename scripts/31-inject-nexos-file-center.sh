#!/usr/bin/env bash
# NexOS File Center: file organization, compression, cleanup, transfers folder, reports.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/64-nexos-file-center.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
rsync
zip
unzip
p7zip-full
thunar
mousepad
file
findutils
coreutils
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/230-nexos-file-center.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin rsync zip unzip p7zip-full thunar mousepad file findutils coreutils; do install_if_available "$p"; done
mkdir -p /opt/nexos/file-center "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/NexOS/Transfers" "$home_dir/NexOS/Reports" "$home_dir/NexOS/Archives" "$home_dir/NexOS/Organized"
cat > "$icon_dir/nexos-file-center.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#60a5fa" stroke-width="4"/><path d="M28 45h34l8 10h30v38a8 8 0 0 1-8 8H36a8 8 0 0 1-8-8z" fill="none" stroke="#38bdf8" stroke-width="7" stroke-linejoin="round"/><path d="M46 68h36M46 82h24" stroke="#e8f7ff" stroke-width="6" stroke-linecap="round"/></svg>
SVG
cat > /usr/local/bin/nexos-file-report <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Reports/file-report-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$out")"
{
echo "NexOS File Report"; echo "================="; date; echo
echo "Home folder size:"; du -sh "$HOME" 2>/dev/null || true; echo
echo "Largest folders:"; du -h -d 2 "$HOME" 2>/dev/null | sort -hr | head -40 || true; echo
echo "Largest files:"; find "$HOME" -type f -printf '%s %p\n' 2>/dev/null | sort -nr | head -40 | awk '{size=$1;$1=""; printf "%.2f MB %s\n", size/1024/1024, $0}' || true
} > "$out"
if command -v mousepad >/dev/null 2>&1; then mousepad "$out" >/dev/null 2>&1 & else xdg-open "$out" >/dev/null 2>&1 & fi
BASH
chmod 0755 /usr/local/bin/nexos-file-report
cat > /usr/local/bin/nexos-archive-folder <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
src="${1:-$HOME/NexOS/Transfers}"
name="$(basename "$src")-$(date +%Y%m%d-%H%M%S).zip"
mkdir -p "$HOME/NexOS/Archives"
zip -r "$HOME/NexOS/Archives/$name" "$src"
notify-send "NexOS Archive" "Created $name" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-archive-folder
cat > /usr/local/bin/nexos-organize-downloads <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
base="$HOME/Downloads"
out="$HOME/NexOS/Organized"
mkdir -p "$out/Images" "$out/Documents" "$out/Archives" "$out/Media" "$out/Other"
[[ -d "$base" ]] || exit 0
find "$base" -maxdepth 1 -type f | while read -r f; do
  ext="${f##*.}"; ext="${ext,,}"
  case "$ext" in
    png|jpg|jpeg|gif|webp|svg) dest="$out/Images" ;;
    pdf|txt|md|doc|docx|xls|xlsx|ppt|pptx) dest="$out/Documents" ;;
    zip|7z|rar|tar|gz) dest="$out/Archives" ;;
    mp3|wav|mp4|mkv|mov|avi) dest="$out/Media" ;;
    *) dest="$out/Other" ;;
  esac
  cp -n "$f" "$dest/" 2>/dev/null || true
done
notify-send "NexOS File Center" "Downloads copied into Organized folders" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-organize-downloads
cat > /usr/local/bin/nexos-file-center <<'PY'
#!/usr/bin/env python3
import shutil, subprocess, tkinter as tk
from tkinter import ttk, messagebox
A={'Folders':[('Home','xdg-open ~'),('Downloads','xdg-open ~/Downloads'),('Transfers','xdg-open ~/NexOS/Transfers'),('Archives','xdg-open ~/NexOS/Archives'),('Organized','xdg-open ~/NexOS/Organized')],'Tools':[('File Report','nexos-file-report'),('Archive Transfers','x-terminal-emulator -e nexos-archive-folder'),('Organize Downloads','nexos-organize-downloads'),('File Manager','thunar')],'System':[('Workspace Suite','nexos-workspace-suite'),('Control Suite','nexos-control-suite'),('Backup Home','x-terminal-emulator -e nexos-backup-home')]}
def run(c):
    e=c.split()[0]
    if shutil.which(e): subprocess.Popen(c.split(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    else: messagebox.showwarning('NexOS File Center',f'{e} is not installed.')
r=tk.Tk(); r.title('NexOS File Center'); r.geometry('920x600'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS File Center',bg='#07111f',fg='#e8f7ff',font=('Sans',30,'bold')).pack(anchor='w',padx=24,pady=18)
nb=ttk.Notebook(r); nb.pack(fill='both',expand=True,padx=18,pady=14)
for cat,items in A.items():
    f=tk.Frame(nb,bg='#07111f',padx=14,pady=14); nb.add(f,text=cat)
    for i,(n,c) in enumerate(items): tk.Button(f,text=n,command=lambda x=c:run(x),bg='#1f2937',fg='#e8f7ff',activebackground='#0ea5e9',relief='flat',padx=14,pady=14,font=('Sans',11,'bold')).grid(row=i//2,column=i%2,padx=8,pady=8,sticky='ew'); f.grid_columnconfigure(i%2,weight=1)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-file-center
for spec in "nexos-file-center|NexOS File Center|System;FileManager;" "nexos-file-report|NexOS File Report|System;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-file-center.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-file-center' not in s: p.write_text(s.replace('\n]', '\n    ("Files+", ["nexos-file-center"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('file center','nexos-file-center','NexOS File Center'),('file report','nexos-file-report','NexOS File Report'),('organize downloads','nexos-organize-downloads','NexOS Organize Downloads')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS File Center:
- Adds file organization, archive helper, reports, transfers/archives/organized folders, dock/menu entries, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/230-nexos-file-center.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/230-nexos-file-center.hook.chroot"
success "Injected NexOS File Center for $NEXOS_EDITION."
