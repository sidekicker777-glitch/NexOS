#!/usr/bin/env bash
# NexOS Search Center: Spotlight/Windows-style launcher for apps, files, settings, commands, and NexOS tools.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/78-nexos-search-center.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
findutils
procps
ripgrep
mlocate
catfish
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/370-nexos-search-center.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin findutils procps ripgrep mlocate catfish; do install_if_available "$p"; done
mkdir -p /opt/nexos/search-center "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/.config/nexos/search-center" "$home_dir/NexOS/Reports"
cat > "$icon_dir/nexos-search-center.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><circle cx="57" cy="57" r="25" fill="none" stroke="#e8f7ff" stroke-width="8"/><path d="M77 77l26 26" stroke="#22c55e" stroke-width="9" stroke-linecap="round"/><path d="M45 57h24" stroke="#38bdf8" stroke-width="6" stroke-linecap="round"/></svg>
SVG
cat > /usr/local/bin/nexos-search-index <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/.config/nexos/search-center"
idx="$HOME/.config/nexos/search-center/index.tsv"
: > "$idx"
# Desktop apps
find /usr/share/applications "$HOME/.local/share/applications" -name '*.desktop' 2>/dev/null | while read -r f; do
  name="$(grep -m1 '^Name=' "$f" 2>/dev/null | cut -d= -f2- || basename "$f")"
  exec="$(grep -m1 '^Exec=' "$f" 2>/dev/null | cut -d= -f2- | sed 's/ *%[A-Za-z]//g' || true)"
  [[ -n "$name" ]] && printf 'app\t%s\t%s\t%s\n' "$name" "$exec" "$f" >> "$idx"
done
# NexOS commands
find /usr/local/bin -maxdepth 1 -type f -executable -name 'nexos-*' 2>/dev/null | sort | while read -r f; do
  n="$(basename "$f")"; printf 'command\t%s\t%s\t%s\n' "$n" "$f" "$f" >> "$idx"
done
# Common folders
for d in "$HOME" "$HOME/NexOS" "$HOME/NexOS/Projects" "$HOME/NexOS/Notes" "$HOME/NexOS/Reports" "$HOME/Downloads" "$HOME/Documents" "$HOME/Games"; do
  [[ -d "$d" ]] && printf 'folder\t%s\txdg-open "%s"\t%s\n' "$(basename "$d")" "$d" "$d" >> "$idx"
done
notify-send "NexOS Search" "Search index updated" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-search-index
cat > /usr/local/bin/nexos-search-report <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Reports/search-report-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$out")"
{
echo "NexOS Search Center Report"; echo "=========================="; date; echo
idx="$HOME/.config/nexos/search-center/index.tsv"
[[ -f "$idx" ]] || nexos-search-index >/dev/null 2>&1 || true
echo "Index: $idx"; [[ -f "$idx" ]] && wc -l "$idx"; echo
echo "Indexed NexOS commands:"; awk -F'\t' '$1=="command"{print $2}' "$idx" 2>/dev/null | head -200 || true; echo
echo "Search tools:"; for c in rg locate updatedb catfish find; do printf '%-10s ' "$c"; command -v "$c" || true; done
} > "$out"
if command -v mousepad >/dev/null 2>&1; then mousepad "$out" >/dev/null 2>&1 & else xdg-open "$out" >/dev/null 2>&1 & fi
BASH
chmod 0755 /usr/local/bin/nexos-search-report
cat > /usr/local/bin/nexos-search-center <<'PY'
#!/usr/bin/env python3
import os, shlex, shutil, subprocess, tkinter as tk
from pathlib import Path
from tkinter import messagebox
HOME=Path.home(); IDX=HOME/'.config/nexos/search-center/index.tsv'
FALLBACK=[('Settings','nexos-settings','command'),('Action Center','nexos-action-center','command'),('Power Center','nexos-power-center','command'),('Software Center','nexos-software-center','command'),('Code Editor','nexos-code-editor','command'),('File Center','nexos-file-center','command'),('Search Report','nexos-search-report','command')]
def build_index():
    if shutil.which('nexos-search-index'): subprocess.call(['nexos-search-index'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
def load():
    if not IDX.exists(): build_index()
    rows=[]
    if IDX.exists():
        for line in IDX.read_text(errors='ignore').splitlines():
            parts=line.split('\t')
            if len(parts)>=4: rows.append((parts[1],parts[2],parts[0],parts[3]))
    for n,c,t in FALLBACK: rows.append((n,c,t,c))
    return rows
ROWS=load()
def run(cmd,path=''):
    if not cmd: return
    try:
        if cmd.startswith('xdg-open') or cmd.startswith('/'): subprocess.Popen(cmd,shell=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        else: subprocess.Popen(shlex.split(cmd),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    except Exception as e: messagebox.showwarning('NexOS Search Center',str(e))
def search_files(q):
    results=[]
    roots=[HOME/'NexOS',HOME/'Downloads',HOME/'Documents',HOME/'Desktop']
    for root in roots:
        if root.exists():
            for p in root.rglob('*'):
                if len(results)>60: return results
                if q.lower() in p.name.lower(): results.append((p.name,'xdg-open '+shlex.quote(str(p)),'file',str(p)))
    return results
def refresh(_=None):
    q=var.get().strip().lower(); lb.delete(0,'end'); matches=[]
    if q:
        for n,c,t,p in ROWS:
            hay=(n+' '+c+' '+t+' '+p).lower()
            if q in hay: matches.append((n,c,t,p))
        if len(q)>=2: matches += search_files(q)
    else:
        matches=ROWS[:80]
    shown.clear()
    for n,c,t,p in matches[:120]:
        shown.append((n,c,t,p)); lb.insert('end',f'[{t}] {n}   {p}')
def open_selected(_=None):
    sel=lb.curselection()
    if not sel: return
    n,c,t,p=shown[sel[0]]; run(c,p)
def open_folder():
    sel=lb.curselection()
    if not sel: return
    n,c,t,p=shown[sel[0]]; pp=Path(p)
    target=pp if pp.is_dir() else pp.parent
    subprocess.Popen(['xdg-open',str(target)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
def rebuild():
    global ROWS
    build_index(); ROWS=load(); refresh(); messagebox.showinfo('NexOS Search','Index rebuilt.')
r=tk.Tk(); r.title('NexOS Search Center'); r.geometry('920x650'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Search Center',bg='#07111f',fg='#e8f7ff',font=('Sans',30,'bold')).pack(anchor='w',padx=24,pady=(20,4))
tk.Label(r,text='Search apps, files, settings, NexOS tools, folders and commands.',bg='#07111f',fg='#9bd5ff').pack(anchor='w',padx=24,pady=(0,12))
var=tk.StringVar(); ent=tk.Entry(r,textvariable=var,bg='#0d172b',fg='#e8f7ff',insertbackground='#38bdf8',relief='flat',font=('Sans',18)); ent.pack(fill='x',padx=24,ipady=12,pady=8); ent.bind('<KeyRelease>',refresh); ent.bind('<Return>',open_selected)
shown=[]; lb=tk.Listbox(r,bg='#0d172b',fg='#e8f7ff',selectbackground='#0ea5e9',relief='flat',font=('DejaVu Sans Mono',10)); lb.pack(fill='both',expand=True,padx=24,pady=10); lb.bind('<Double-1>',open_selected)
bar=tk.Frame(r,bg='#07111f'); bar.pack(fill='x',padx=24,pady=14)
for n,c in [('Open',open_selected),('Open Folder',open_folder),('Rebuild Index',rebuild),('Report',lambda:run('nexos-search-report')),('Close',r.destroy)]: tk.Button(bar,text=n,command=c,bg='#0ea5e9' if n=='Open' else '#1f2937',fg='white' if n=='Open' else '#e8f7ff',relief='flat',padx=14,pady=10).pack(side='left',padx=4)
refresh(); ent.focus_set(); r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-search-center
cat > /usr/local/bin/nexos-search <<'BASH'
#!/usr/bin/env bash
nexos-search-center "$@"
BASH
chmod 0755 /usr/local/bin/nexos-search
for spec in "nexos-search-center|NexOS Search Center|Utility;System;" "nexos-search-report|NexOS Search Report|System;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-search-center.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-search-center' not in s: p.write_text(s.replace('\n]', '\n    ("Search", ["nexos-search-center"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /usr/local/bin/nexos-action-center ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-action-center'); s=p.read_text()
if "('Search','nexos-search-center')" not in s:
    s=s.replace("('Settings','nexos-settings')", "('Search','nexos-search-center'),('Settings','nexos-settings')")
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-action-center; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('search center','nexos-search-center','NexOS Search Center'),('search','nexos-search-center','NexOS Search Center'),('search report','nexos-search-report','NexOS Search Report')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Search Center:
- Adds launcher/search UI for apps, files, settings, NexOS commands, folders, index rebuilds, reports, dock/menu entries, Action Center integration, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/370-nexos-search-center.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/370-nexos-search-center.hook.chroot"
success "Injected NexOS Search Center for $NEXOS_EDITION."
