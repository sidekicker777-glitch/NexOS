#!/usr/bin/env bash
# NexOS Code Editor: VS Code-style built-in editor with file tree, tabs, terminal/build shortcuts.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/68-nexos-code-editor.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
git
make
cmake
build-essential
python3-venv
nodejs
npm
ripgrep
mousepad
xfce4-terminal
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/270-nexos-code-editor.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin git make cmake build-essential python3-venv nodejs npm ripgrep mousepad xfce4-terminal; do install_if_available "$p"; done
mkdir -p /opt/nexos/code-editor "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/NexOS/Projects" "$home_dir/NexOS/Reports" "$home_dir/.config/nexos/code-editor"
cat > "$icon_dir/nexos-code-editor.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><path d="M46 40L24 64l22 24M82 40l22 24-22 24" fill="none" stroke="#e8f7ff" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/><path d="M70 33L56 95" stroke="#22c55e" stroke-width="8" stroke-linecap="round"/></svg>
SVG
cat > /usr/local/bin/nexos-code-runner <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
file="${1:-}"
[[ -f "$file" ]] || { echo "Usage: nexos-code-runner <file>"; exit 1; }
cd "$(dirname "$file")"
base="$(basename "$file")"
ext="${base##*.}"
case "$ext" in
  py) python3 "$base" ;;
  js) node "$base" ;;
  sh) bash "$base" ;;
  lua) lua "$base" ;;
  c) gcc "$base" -o /tmp/nexos-code-run && /tmp/nexos-code-run ;;
  cpp|cc|cxx) g++ "$base" -o /tmp/nexos-code-run && /tmp/nexos-code-run ;;
  html|htm) xdg-open "$base" ;;
  *) echo "No runner configured for .$ext" ;;
esac
echo; echo "Press Enter to close"; read -r _ || true
BASH
chmod 0755 /usr/local/bin/nexos-code-runner
cat > /usr/local/bin/nexos-code-build-report <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Reports/code-tools-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$out")"
{
echo "NexOS Code Tools Report"; echo "======================="; date; echo
for c in python3 node npm git gcc g++ make cmake rg lua; do printf '%-10s ' "$c"; command -v "$c" || true; done
} > "$out"
if command -v mousepad >/dev/null 2>&1; then mousepad "$out" >/dev/null 2>&1 & else xdg-open "$out" >/dev/null 2>&1 & fi
BASH
chmod 0755 /usr/local/bin/nexos-code-build-report
cat > /usr/local/bin/nexos-code-editor <<'PY'
#!/usr/bin/env python3
import os, shutil, subprocess, tkinter as tk
from pathlib import Path
from tkinter import ttk, filedialog, messagebox, simpledialog
ROOT_DEFAULT=Path.home()/'NexOS'/'Projects'; ROOT_DEFAULT.mkdir(parents=True,exist_ok=True)
class Editor:
    def __init__(self):
        self.root=tk.Tk(); self.root.title('NexOS Code Editor'); self.root.geometry('1220x760'); self.root.configure(bg='#0b1020')
        self.project=ROOT_DEFAULT; self.open_files={}; self.current=None
        self.make_ui(); self.load_tree(); self.root.mainloop()
    def make_ui(self):
        top=tk.Frame(self.root,bg='#020617',height=42); top.pack(fill='x')
        tk.Label(top,text='NexOS Code Editor',bg='#020617',fg='#e8f7ff',font=('Sans',14,'bold')).pack(side='left',padx=12)
        for name,cmd in [('Open Folder',self.open_folder),('New File',self.new_file),('Save',self.save),('Run',self.run_file),('Terminal',self.terminal),('Search',self.search),('AI',self.ai),('Tools',self.tools)]:
            tk.Button(top,text=name,command=cmd,bg='#111827',fg='#dbeafe',activebackground='#0ea5e9',relief='flat',padx=10).pack(side='left',padx=2,pady=6)
        main=tk.PanedWindow(self.root,orient='horizontal',bg='#0b1020',sashwidth=4); main.pack(fill='both',expand=True)
        side=tk.Frame(main,bg='#0d172b'); main.add(side,width=280)
        tk.Label(side,text='EXPLORER',bg='#0d172b',fg='#93c5fd',font=('Sans',10,'bold')).pack(anchor='w',padx=10,pady=8)
        self.tree=ttk.Treeview(side,show='tree'); self.tree.pack(fill='both',expand=True,padx=8,pady=(0,8)); self.tree.bind('<Double-1>',self.tree_open)
        right=tk.Frame(main,bg='#0b1020'); main.add(right)
        self.tabs=ttk.Notebook(right); self.tabs.pack(fill='both',expand=True); self.tabs.bind('<<NotebookTabChanged>>',self.tab_changed)
        bottom=tk.Frame(right,bg='#020617',height=110); bottom.pack(fill='x')
        tk.Label(bottom,text='OUTPUT',bg='#020617',fg='#93c5fd',font=('Sans',9,'bold')).pack(anchor='w',padx=8)
        self.output=tk.Text(bottom,height=5,bg='#020617',fg='#dbeafe',insertbackground='#e8f7ff',relief='flat'); self.output.pack(fill='both',expand=True,padx=8,pady=(0,8))
    def log(self,s): self.output.insert('end',s+'\n'); self.output.see('end')
    def load_tree(self):
        self.tree.delete(*self.tree.get_children()); root_id=self.tree.insert('', 'end', text=str(self.project), open=True, values=[str(self.project)])
        def add(parent,path,depth=0):
            if depth>3: return
            try: items=sorted(path.iterdir(), key=lambda p:(p.is_file(),p.name.lower()))
            except Exception: return
            for p in items:
                if p.name.startswith('.') and p.name not in ('.env','.gitignore'): continue
                node=self.tree.insert(parent,'end',text=p.name,open=False,values=[str(p)])
                if p.is_dir(): add(node,p,depth+1)
        add(root_id,self.project)
    def open_folder(self):
        d=filedialog.askdirectory(initialdir=str(self.project))
        if d: self.project=Path(d); self.load_tree()
    def tree_open(self,_e=None):
        item=self.tree.focus(); vals=self.tree.item(item,'values')
        if not vals: return
        p=Path(vals[0])
        if p.is_file(): self.open_file(p)
    def open_file(self,p):
        if str(p) in self.open_files:
            self.tabs.select(self.open_files[str(p)]['frame']); return
        frame=tk.Frame(self.tabs,bg='#0b1020')
        text=tk.Text(frame,bg='#0f172a',fg='#e5e7eb',insertbackground='#38bdf8',undo=True,wrap='none',font=('DejaVu Sans Mono',11),relief='flat')
        y=tk.Scrollbar(frame,command=text.yview); x=tk.Scrollbar(frame,orient='horizontal',command=text.xview)
        text.configure(yscrollcommand=y.set,xscrollcommand=x.set)
        text.grid(row=0,column=0,sticky='nsew'); y.grid(row=0,column=1,sticky='ns'); x.grid(row=1,column=0,sticky='ew')
        frame.grid_rowconfigure(0,weight=1); frame.grid_columnconfigure(0,weight=1)
        try: text.insert('1.0',p.read_text(errors='replace'))
        except Exception as e: text.insert('1.0',str(e))
        self.tabs.add(frame,text=p.name); self.tabs.select(frame); self.open_files[str(p)]={'path':p,'text':text,'frame':frame}; self.current=str(p); self.highlight(text)
        text.bind('<KeyRelease>',lambda e,t=text:self.highlight(t))
    def tab_changed(self,_e=None):
        sel=self.tabs.select()
        for k,v in self.open_files.items():
            if str(v['frame'])==sel: self.current=k
    def save(self):
        if not self.current: return
        v=self.open_files[self.current]; v['path'].write_text(v['text'].get('1.0','end-1c')); self.log('Saved '+str(v['path']))
    def new_file(self):
        name=simpledialog.askstring('New File','File name:')
        if not name: return
        p=self.project/name; p.parent.mkdir(parents=True,exist_ok=True); p.touch(exist_ok=True); self.load_tree(); self.open_file(p)
    def run_file(self):
        if not self.current: return
        self.save(); self.term(['nexos-code-runner',self.current])
    def terminal(self): self.term(['bash'])
    def term(self,cmd):
        term=shutil.which('xfce4-terminal') or shutil.which('x-terminal-emulator')
        if term: subprocess.Popen([term,'--working-directory',str(self.project),'-e']+cmd,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    def search(self):
        q=simpledialog.askstring('Search Project','Search text:')
        if not q: return
        self.output.delete('1.0','end')
        for p in self.project.rglob('*'):
            if p.is_file() and p.stat().st_size<500000:
                try:
                    for i,line in enumerate(p.read_text(errors='ignore').splitlines(),1):
                        if q.lower() in line.lower(): self.log(f'{p.relative_to(self.project)}:{i}: {line[:160]}')
                except Exception: pass
    def ai(self):
        if shutil.which('nexos-assistant-toggle'): subprocess.Popen(['nexos-assistant-toggle'])
    def tools(self):
        if shutil.which('nexos-code-build-report'): subprocess.Popen(['nexos-code-build-report'])
    def highlight(self,text):
        for tag in ('kw','str','com'): text.tag_remove(tag,'1.0','end')
        text.tag_config('kw',foreground='#93c5fd'); text.tag_config('str',foreground='#86efac'); text.tag_config('com',foreground='#94a3b8')
        kws=['def','class','function','const','let','var','if','else','for','while','return','import','from','local','end','then','public','private','void','int','string']
        for kw in kws:
            start='1.0'
            while True:
                pos=text.search(r'\m'+kw+r'\M',start,'end',regexp=True)
                if not pos: break
                end=f'{pos}+{len(kw)}c'; text.tag_add('kw',pos,end); start=end
        for mark in ['#','//']:
            start='1.0'
            while True:
                pos=text.search(mark,start,'end')
                if not pos: break
                line=pos.split('.')[0]; text.tag_add('com',pos,f'{line}.end'); start=f'{line}.end'
Editor()
PY
chmod 0755 /usr/local/bin/nexos-code-editor
cat > /usr/share/applications/nexos-code-editor.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Code Editor
Comment=VS Code-style NexOS editor with project tree, tabs, run and terminal shortcuts
Exec=nexos-code-editor
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-code-editor.svg
Terminal=false
Categories=Development;IDE;
X-XFCE-Trusted=true
DESKTOP
chmod 0755 /usr/share/applications/nexos-code-editor.desktop
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-code-editor' not in s: p.write_text(s.replace('\n]', '\n    ("Code", ["nexos-code-editor"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('code editor','nexos-code-editor','NexOS Code Editor'),('editor','nexos-code-editor','NexOS Code Editor'),('code tools','nexos-code-build-report','NexOS Code Tools Report')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Code Editor:
- Adds VS Code-style editor with Explorer tree, tabs, save/new/open folder, run file, terminal, search, simple syntax highlighting, tool report, dock/menu entries, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/270-nexos-code-editor.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/270-nexos-code-editor.hook.chroot"
success "Injected NexOS Code Editor for $NEXOS_EDITION."
