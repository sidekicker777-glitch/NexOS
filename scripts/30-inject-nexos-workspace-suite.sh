#!/usr/bin/env bash
# NexOS Workspace Suite: project, notes, screenshot, clipboard, workflow folders.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/63-nexos-workspace-suite.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
xclip
scrot
rsync
zip
unzip
p7zip-full
mousepad
thunar
xfce4-terminal
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/220-nexos-workspace-suite.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin xclip scrot rsync zip unzip p7zip-full mousepad thunar xfce4-terminal; do install_if_available "$p"; done
mkdir -p /opt/nexos/workspace-suite "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/NexOS/Projects" "$home_dir/NexOS/Notes" "$home_dir/NexOS/Tasks" "$home_dir/NexOS/Screenshots" "$home_dir/NexOS/Templates" "$home_dir/NexOS/Transfers" "$home_dir/.config/nexos/workspace"
cat > "$icon_dir/nexos-workspace-suite.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#60a5fa" stroke-width="4"/><path d="M30 42h30l8 10h30v38a8 8 0 0 1-8 8H38a8 8 0 0 1-8-8z" fill="none" stroke="#a78bfa" stroke-width="7" stroke-linejoin="round"/><path d="M46 65h36M46 80h25" stroke="#e8f7ff" stroke-width="6" stroke-linecap="round"/></svg>
SVG
cat > /usr/local/bin/nexos-quick-note <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/NexOS/Notes"
f="$HOME/NexOS/Notes/note-$(date +%Y%m%d-%H%M%S).md"
printf '# NexOS Note\n\nCreated: %s\n\n' "$(date)" > "$f"
if command -v mousepad >/dev/null 2>&1; then mousepad "$f" >/dev/null 2>&1 & else xdg-open "$f" >/dev/null 2>&1 & fi
BASH
chmod 0755 /usr/local/bin/nexos-quick-note
cat > /usr/local/bin/nexos-screenshot <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/NexOS/Screenshots"
out="$HOME/NexOS/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png"
if command -v scrot >/dev/null 2>&1; then scrot "$out"; notify-send "NexOS Screenshot" "Saved screenshot" 2>/dev/null || true; else notify-send "NexOS" "No screenshot tool installed" 2>/dev/null || true; fi
BASH
chmod 0755 /usr/local/bin/nexos-screenshot
cat > /usr/local/bin/nexos-clipboard-save <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/NexOS/Notes"
out="$HOME/NexOS/Notes/clipboard-$(date +%Y%m%d-%H%M%S).txt"
if command -v xclip >/dev/null 2>&1; then xclip -selection clipboard -o > "$out" 2>/dev/null || true; fi
notify-send "NexOS Clipboard" "Saved clipboard" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-clipboard-save
cat > /usr/local/bin/nexos-new-project <<'PY'
#!/usr/bin/env python3
import subprocess, tkinter as tk
from pathlib import Path
from tkinter import ttk, messagebox
TEMPLATES={'Code Project':['src','docs','assets','tests'],'Game Project':['assets','scripts','levels','docs','builds'],'Website Project':['public','src','assets','docs'],'Mod Project':['client','server','shared','assets','docs']}
ROOT=Path.home()/'NexOS'/'Projects'; ROOT.mkdir(parents=True,exist_ok=True)
def create():
    name=name_var.get().strip().replace('/','-'); kind=kind_var.get()
    if not name: messagebox.showwarning('NexOS','Enter a project name.'); return
    d=ROOT/name; d.mkdir(parents=True,exist_ok=True)
    for f in TEMPLATES.get(kind,[]): (d/f).mkdir(exist_ok=True)
    (d/'README.md').write_text(f'# {name}\n\nCreated with NexOS Workspace Suite.\n')
    subprocess.Popen(['xdg-open',str(d)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL); r.destroy()
r=tk.Tk(); r.title('NexOS New Project'); r.geometry('620x340'); r.configure(bg='#07111f')
tk.Label(r,text='Create NexOS Project',bg='#07111f',fg='#e8f7ff',font=('Sans',26,'bold')).pack(anchor='w',padx=24,pady=22)
f=tk.Frame(r,bg='#07111f',padx=24); f.pack(fill='both',expand=True)
name_var=tk.StringVar(); kind_var=tk.StringVar(value='Code Project')
tk.Label(f,text='Project Name',bg='#07111f',fg='#e8f7ff').pack(anchor='w'); tk.Entry(f,textvariable=name_var,bg='#0d172b',fg='#e8f7ff',insertbackground='#e8f7ff',relief='flat').pack(fill='x',ipady=9,pady=6)
tk.Label(f,text='Template',bg='#07111f',fg='#e8f7ff').pack(anchor='w'); ttk.Combobox(f,textvariable=kind_var,values=list(TEMPLATES.keys()),state='readonly').pack(fill='x',pady=6)
tk.Button(f,text='Create Project',command=create,bg='#0ea5e9',fg='white',relief='flat',padx=20,pady=11).pack(anchor='e',pady=18)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-new-project
cat > /usr/local/bin/nexos-workspace-suite <<'PY'
#!/usr/bin/env python3
import shutil, subprocess, tkinter as tk
from tkinter import messagebox
A=[('New Project','Create structured project folders','nexos-new-project'),('Quick Note','Create a note','nexos-quick-note'),('Screenshot','Save screenshot','nexos-screenshot'),('Save Clipboard','Save clipboard text','nexos-clipboard-save'),('Projects','Open projects','xdg-open ~/NexOS/Projects'),('Notes','Open notes','xdg-open ~/NexOS/Notes'),('Transfers','Open transfers','xdg-open ~/NexOS/Transfers'),('Control Suite','Open OS hub','nexos-control-suite'),('AI Assistant','Open assistant','nexos-assistant-toggle')]
def run(c):
    e=c.split()[0]
    if shutil.which(e): subprocess.Popen(c.split(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    else: messagebox.showwarning('NexOS',f'{e} is not installed.')
r=tk.Tk(); r.title('NexOS Workspace Suite'); r.geometry('920x620'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Workspace Suite',bg='#07111f',fg='#e8f7ff',font=('Sans',30,'bold')).pack(anchor='w',padx=24,pady=18)
f=tk.Frame(r,bg='#07111f',padx=18); f.pack(fill='both',expand=True)
for i,(n,d,c) in enumerate(A):
    card=tk.Frame(f,bg='#0d172b',padx=14,pady=12,highlightbackground='#294866',highlightthickness=1); card.grid(row=i//2,column=i%2,padx=8,pady=8,sticky='nsew'); f.grid_columnconfigure(i%2,weight=1)
    tk.Label(card,text=n,bg='#0d172b',fg='#e8f7ff',font=('Sans',14,'bold')).pack(anchor='w'); tk.Label(card,text=d,bg='#0d172b',fg='#a7bdd8').pack(anchor='w'); tk.Button(card,text='Open',command=lambda x=c:run(x),bg='#1f2937',fg='#e8f7ff',relief='flat').pack(anchor='e')
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-workspace-suite
for spec in "nexos-workspace-suite|NexOS Workspace Suite" "nexos-new-project|NexOS New Project" "nexos-quick-note|NexOS Quick Note" "nexos-screenshot|NexOS Screenshot" "nexos-clipboard-save|NexOS Clipboard Save"; do
 IFS='|' read -r exec name <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-workspace-suite.svg
Terminal=false
Categories=Utility;Office;
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-workspace-suite' not in s: p.write_text(s.replace('\n]', '\n    ("Workspace", ["nexos-workspace-suite"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('workspace suite','nexos-workspace-suite','NexOS Workspace Suite'),('new project','nexos-new-project','NexOS New Project'),('quick note','nexos-quick-note','NexOS Quick Note'),('screenshot','nexos-screenshot','NexOS Screenshot'),('save clipboard','nexos-clipboard-save','NexOS Clipboard Save')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Workspace Suite:
- Adds project creator, quick notes, screenshots, clipboard save, workflow folders, dock/menu entries, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/220-nexos-workspace-suite.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/220-nexos-workspace-suite.hook.chroot"
success "Injected NexOS Workspace Suite for $NEXOS_EDITION."
