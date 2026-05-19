#!/usr/bin/env bash
# NexOS First-Run Wizard: welcome/setup flow for display, theme, assistant, gaming, workspace.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/70-nexos-first-run-wizard.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
xfconf
x11-xserver-utils
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/290-nexos-first-run-wizard.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin xfconf x11-xserver-utils; do install_if_available "$p"; done
mkdir -p /opt/nexos/first-run "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/.config/autostart" "$home_dir/.config/nexos/first-run" "$home_dir/NexOS/Projects" "$home_dir/NexOS/Notes" "$home_dir/NexOS/Tasks" "$home_dir/NexOS/Reports" "$home_dir/Games/NexOS/ROMs" "$home_dir/Games/NexOS/BIOS" "$home_dir/Games/NexOS/Saves"
cat > "$icon_dir/nexos-first-run.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><path d="M35 68l18 18 40-46" fill="none" stroke="#22c55e" stroke-width="10" stroke-linecap="round" stroke-linejoin="round"/><circle cx="93" cy="30" r="8" fill="#a78bfa"/></svg>
SVG
cat > /usr/local/bin/nexos-first-run-reset <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
rm -f "$HOME/.config/nexos/first-run/completed"
notify-send "NexOS" "First-run wizard reset" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-first-run-reset
cat > /usr/local/bin/nexos-first-run-wizard <<'PY'
#!/usr/bin/env python3
import json, shutil, subprocess, tkinter as tk
from pathlib import Path
from tkinter import ttk, messagebox
HOME=Path.home(); STATE=HOME/'.config/nexos/first-run/completed'; CONF=HOME/'.config/nexos/first-run/settings.json'
for p in [HOME/'NexOS/Projects',HOME/'NexOS/Notes',HOME/'NexOS/Tasks',HOME/'NexOS/Reports',HOME/'Games/NexOS/ROMs',HOME/'Games/NexOS/BIOS',HOME/'Games/NexOS/Saves']:
    p.mkdir(parents=True,exist_ok=True)
def run(cmd):
    e=cmd.split()[0]
    if shutil.which(e): subprocess.Popen(cmd.split(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
def finish(data):
    CONF.parent.mkdir(parents=True,exist_ok=True); CONF.write_text(json.dumps(data,indent=2)); STATE.write_text('completed')
class W:
    def __init__(self):
        self.i=0; self.data={'theme':'NexOS Dark','assistant':True,'gaming':True}
        self.r=tk.Tk(); self.r.title('Welcome to NexOS'); self.r.geometry('900x610'); self.r.configure(bg='#07111f')
        self.t=tk.Label(self.r,text='',bg='#07111f',fg='#e8f7ff',font=('Sans',32,'bold')); self.t.pack(anchor='w',padx=32,pady=(28,6))
        self.s=tk.Label(self.r,text='',bg='#07111f',fg='#9bd5ff',font=('Sans',13),wraplength=800,justify='left'); self.s.pack(anchor='w',padx=32,pady=(0,18))
        self.b=tk.Frame(self.r,bg='#0d172b',padx=22,pady=22,highlightbackground='#294866',highlightthickness=1); self.b.pack(fill='both',expand=True,padx=32,pady=10)
        nav=tk.Frame(self.r,bg='#07111f'); nav.pack(fill='x',padx=32,pady=18)
        self.back=tk.Button(nav,text='Back',command=self.prev,bg='#1f2937',fg='#e8f7ff',relief='flat',padx=18,pady=10); self.back.pack(side='left')
        self.next=tk.Button(nav,text='Next',command=self.next_step,bg='#0ea5e9',fg='white',relief='flat',padx=22,pady=10); self.next.pack(side='right')
        self.render(); self.r.mainloop()
    def clear(self):
        for w in self.b.winfo_children(): w.destroy()
    def btn(self,text,cmd): tk.Button(self.b,text=text,command=cmd,bg='#1f2937',fg='#e8f7ff',activebackground='#0ea5e9',relief='flat',padx=16,pady=12,font=('Sans',11,'bold')).pack(fill='x',pady=6)
    def render(self):
        self.clear(); self.back.config(state='normal' if self.i else 'disabled'); self.next.config(text='Finish' if self.i==5 else 'Next')
        [self.welcome,self.display,self.theme,self.assistant,self.tools,self.done][self.i]()
    def welcome(self):
        self.t.config(text='Welcome to NexOS'); self.s.config(text='This wizard prepares your desktop, display, theme, assistant, gaming folders, workspace, updates and tools.')
        tk.Label(self.b,text='NexOS is being set up as your own OS experience, not a plain Debian desktop.',bg='#0d172b',fg='#e8f7ff',font=('Sans',14),wraplength=760,justify='left').pack(anchor='w')
    def display(self):
        self.t.config(text='Display setup'); self.s.config(text='Fix VM sizing and open driver/display tools.')
        self.btn('Run NexOS Display Fix',lambda:run('nexos-display-fix')); self.btn('Open Display Settings',lambda:run('xfce4-display-settings')); self.btn('Open Driver Center',lambda:run('nexos-driver-center'))
    def theme(self):
        self.t.config(text='Choose style'); self.s.config(text='Pick a starting NexOS look.')
        v=tk.StringVar(value=self.data['theme'])
        for t in ['NexOS Dark','NexOS Classic','High Contrast']:
            tk.Radiobutton(self.b,text=t,variable=v,value=t,bg='#0d172b',fg='#e8f7ff',selectcolor='#111827',activebackground='#0d172b',command=lambda:self.data.update(theme=v.get()),font=('Sans',13)).pack(anchor='w',pady=6)
        self.btn('Open Theme Center',lambda:run('nexos-theme-center'))
    def assistant(self):
        self.t.config(text='NexOS Assistant'); self.s.config(text='Open the assistant and AI settings.')
        self.btn('Open Assistant',lambda:run('nexos-assistant-toggle')); self.btn('Open AI Settings',lambda:run('nexos-ai-settings'))
    def tools(self):
        self.t.config(text='Gaming, workspace and code'); self.s.config(text='Prepare your game library and creative/dev workspace.')
        self.btn('Open Gaming Center',lambda:run('nexos-gaming-center')); self.btn('Open Workspace Suite',lambda:run('nexos-workspace-suite')); self.btn('Open Code Editor',lambda:run('nexos-code-editor'))
    def done(self):
        self.t.config(text='Finish setup'); self.s.config(text='Save setup choices and open the main hubs.')
        self.btn('Open NexOS Settings',lambda:run('nexos-settings')); self.btn('Open Control Suite',lambda:run('nexos-control-suite')); self.btn('Open Update Center',lambda:run('nexos-update-center'))
    def prev(self): self.i=max(0,self.i-1); self.render()
    def next_step(self):
        if self.i<5: self.i+=1; self.render(); return
        finish(self.data); messagebox.showinfo('NexOS','First-run setup complete.'); self.r.destroy()
W()
PY
chmod 0755 /usr/local/bin/nexos-first-run-wizard
cat > "$home_dir/.config/autostart/nexos-first-run-wizard.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS First-Run Wizard
Exec=sh -c 'test -f "$HOME/.config/nexos/first-run/completed" || nexos-first-run-wizard'
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-first-run.svg
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP
cat > /usr/share/applications/nexos-first-run-wizard.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS First-Run Wizard
Exec=nexos-first-run-wizard
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-first-run.svg
Terminal=false
Categories=Settings;System;
X-XFCE-Trusted=true
DESKTOP
chmod 0755 /usr/share/applications/nexos-first-run-wizard.desktop
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-first-run-wizard' not in s: p.write_text(s.replace('\n]', '\n    ("Setup", ["nexos-first-run-wizard"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('first run wizard','nexos-first-run-wizard','NexOS First-Run Wizard'),('setup wizard','nexos-first-run-wizard','NexOS First-Run Wizard')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS First-Run Wizard:
- Adds first boot setup for display, theme, assistant, gaming, workspace, code editor, updates, settings, and control suite.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/290-nexos-first-run-wizard.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/290-nexos-first-run-wizard.hook.chroot"
success "Injected NexOS First-Run Wizard for $NEXOS_EDITION."
