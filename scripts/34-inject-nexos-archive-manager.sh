#!/usr/bin/env bash
# NexOS Archive Manager: GUI/helpers for ZIP/7Z/TAR extract and create.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/67-nexos-archive-manager.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
zip
unzip
p7zip-full
tar
gzip
bzip2
xz-utils
file
thunar
mousepad
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/260-nexos-archive-manager.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin zip unzip p7zip-full p7zip-rar tar gzip bzip2 xz-utils file thunar mousepad; do install_if_available "$p"; done
mkdir -p /opt/nexos/archive-manager "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/NexOS/Archives" "$home_dir/NexOS/Extracted" "$home_dir/NexOS/Reports"
cat > "$icon_dir/nexos-archive-manager.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#facc15" stroke-width="4"/><rect x="36" y="27" width="56" height="74" rx="8" fill="none" stroke="#38bdf8" stroke-width="7"/><path d="M58 31v14h12V31M58 59h12M58 73h12M58 87h12" stroke="#e8f7ff" stroke-width="5" stroke-linecap="round"/></svg>
SVG
cat > /usr/local/bin/nexos-extract-archive <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
a="${1:-}"
[[ -f "$a" ]] || { echo "Usage: nexos-extract-archive <archive> [destination]"; exit 1; }
d="${2:-$HOME/NexOS/Extracted/$(basename "$a")-extracted}"
mkdir -p "$d"
case "${a,,}" in
 *.zip) unzip -o "$a" -d "$d" ;;
 *.7z|*.rar) 7z x -y -o"$d" "$a" ;;
 *.tar) tar -xf "$a" -C "$d" ;;
 *.tar.gz|*.tgz) tar -xzf "$a" -C "$d" ;;
 *.tar.bz2|*.tbz2) tar -xjf "$a" -C "$d" ;;
 *.tar.xz|*.txz) tar -xJf "$a" -C "$d" ;;
 *.gz) cp "$a" "$d/"; gunzip -f "$d/$(basename "$a")" ;;
 *) 7z x -y -o"$d" "$a" ;;
esac
notify-send "NexOS Archive Manager" "Extracted to $d" 2>/dev/null || true
xdg-open "$d" >/dev/null 2>&1 &
BASH
chmod 0755 /usr/local/bin/nexos-extract-archive
cat > /usr/local/bin/nexos-create-archive <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
src="${1:-}"
[[ -e "$src" ]] || { echo "Usage: nexos-create-archive <file-or-folder> [output.zip]"; exit 1; }
mkdir -p "$HOME/NexOS/Archives"
out="${2:-$HOME/NexOS/Archives/$(basename "$src")-$(date +%Y%m%d-%H%M%S).zip}"
zip -r "$out" "$src"
notify-send "NexOS Archive Manager" "Created archive" 2>/dev/null || true
xdg-open "$(dirname "$out")" >/dev/null 2>&1 &
BASH
chmod 0755 /usr/local/bin/nexos-create-archive
cat > /usr/local/bin/nexos-archive-manager <<'PY'
#!/usr/bin/env python3
import shutil, subprocess, tkinter as tk
from pathlib import Path
from tkinter import ttk, filedialog, messagebox
ARCH=Path.home()/'NexOS'/'Archives'; EXT=Path.home()/'NexOS'/'Extracted'; ARCH.mkdir(parents=True,exist_ok=True); EXT.mkdir(parents=True,exist_ok=True)
def run(c):
    e=c[0] if isinstance(c,list) else c.split()[0]
    if shutil.which(e): subprocess.Popen(c if isinstance(c,list) else c.split(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    else: messagebox.showwarning('NexOS Archive Manager',f'{e} is not installed.')
def pick_archive():
    f=filedialog.askopenfilename(title='Choose archive')
    if f: archive_var.set(f)
def pick_src():
    f=filedialog.askopenfilename(title='Choose file') or filedialog.askdirectory(title='Choose folder')
    if f: src_var.set(f)
def extract():
    a=archive_var.get().strip()
    if not a: messagebox.showwarning('NexOS','Pick an archive first.'); return
    run(['nexos-extract-archive',a,str(EXT)])
def create():
    s=src_var.get().strip()
    if not s: messagebox.showwarning('NexOS','Pick a file or folder first.'); return
    run(['nexos-create-archive',s])
r=tk.Tk(); r.title('NexOS Archive Manager'); r.geometry('900x600'); r.configure(bg='#07111f')
archive_var=tk.StringVar(); src_var=tk.StringVar()
tk.Label(r,text='NexOS Archive Manager',bg='#07111f',fg='#e8f7ff',font=('Sans',30,'bold')).pack(anchor='w',padx=24,pady=18)
nb=ttk.Notebook(r); nb.pack(fill='both',expand=True,padx=18,pady=14)
ex=tk.Frame(nb,bg='#07111f',padx=18,pady=18); nb.add(ex,text='Extract')
tk.Entry(ex,textvariable=archive_var,bg='#0d172b',fg='#e8f7ff',insertbackground='#e8f7ff',relief='flat').pack(fill='x',ipady=8,pady=8); tk.Button(ex,text='Browse Archive',command=pick_archive,bg='#1f2937',fg='#e8f7ff',relief='flat').pack(anchor='e'); tk.Button(ex,text='Extract to NexOS/Extracted',command=extract,bg='#0ea5e9',fg='white',relief='flat',padx=20,pady=12).pack(anchor='e',pady=24)
cr=tk.Frame(nb,bg='#07111f',padx=18,pady=18); nb.add(cr,text='Create')
tk.Entry(cr,textvariable=src_var,bg='#0d172b',fg='#e8f7ff',insertbackground='#e8f7ff',relief='flat').pack(fill='x',ipady=8,pady=8); tk.Button(cr,text='Browse Source',command=pick_src,bg='#1f2937',fg='#e8f7ff',relief='flat').pack(anchor='e'); tk.Button(cr,text='Create ZIP',command=create,bg='#16a34a',fg='white',relief='flat',padx=20,pady=12).pack(anchor='e',pady=24)
tools=tk.Frame(nb,bg='#07111f',padx=18,pady=18); nb.add(tools,text='Tools')
for n,c in [('Open Archives',['xdg-open',str(ARCH)]),('Open Extracted',['xdg-open',str(EXT)]),('File Center',['nexos-file-center'])]: tk.Button(tools,text=n,command=lambda x=c:run(x),bg='#1f2937',fg='#e8f7ff',relief='flat',padx=16,pady=12).pack(fill='x',pady=6)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-archive-manager
for spec in "nexos-archive-manager|NexOS Archive Manager|Utility;Archiving;" "nexos-extract-archive|NexOS Extract Archive|Utility;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-archive-manager.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-archive-manager' not in s: p.write_text(s.replace('\n]', '\n    ("Archive", ["nexos-archive-manager"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
d['archive manager']={'label':'NexOS Archive Manager','commands':['nexos-archive-manager'],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Archive Manager:
- Adds archive extraction/creation GUI, extract/create helpers, folders, dock/menu entries, and assistant catalog entry.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/260-nexos-archive-manager.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/260-nexos-archive-manager.hook.chroot"
success "Injected NexOS Archive Manager for $NEXOS_EDITION."
