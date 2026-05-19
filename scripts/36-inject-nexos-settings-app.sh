#!/usr/bin/env bash
# NexOS Settings: custom settings replacement hub for display, sound, input, appearance, apps, updates, drivers, storage, privacy, startup.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/69-nexos-settings-app.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
xfconf
xfce4-settings
pavucontrol
network-manager-gnome
arandr
brightnessctl
x11-xserver-utils
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/280-nexos-settings-app.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin xfconf xfce4-settings pavucontrol network-manager-gnome arandr brightnessctl x11-xserver-utils; do install_if_available "$p"; done
mkdir -p /opt/nexos/settings-app "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/NexOS/Reports" "$home_dir/.config/nexos/settings"
cat > "$icon_dir/nexos-settings.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><circle cx="64" cy="64" r="25" fill="none" stroke="#22c55e" stroke-width="8"/><circle cx="64" cy="64" r="9" fill="#e8f7ff"/><path d="M64 25v13M64 90v13M25 64h13M90 64h13M36 36l9 9M83 83l9 9M92 36l-9 9M45 83l-9 9" stroke="#e8f7ff" stroke-width="6" stroke-linecap="round"/></svg>
SVG
cat > /usr/local/bin/nexos-settings-report <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Reports/settings-report-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$out")"
{
echo "NexOS Settings Report"; echo "====================="; date; echo
echo "Display:"; xrandr --query 2>/dev/null || true; echo
echo "Theme:"; xfconf-query -c xsettings -l -v 2>/dev/null | grep -E 'Theme|Icon|Font' || true; echo
echo "Keyboard/mouse:"; xfconf-query -c keyboards -l -v 2>/dev/null || true; xfconf-query -c pointers -l -v 2>/dev/null || true; echo
echo "Startup apps:"; find "$HOME/.config/autostart" /etc/xdg/autostart -maxdepth 1 -name '*.desktop' -printf '%p\n' 2>/dev/null || true; echo
echo "NexOS tools:"; ls /usr/local/bin/nexos-* 2>/dev/null || true
} > "$out"
if command -v mousepad >/dev/null 2>&1; then mousepad "$out" >/dev/null 2>&1 & else xdg-open "$out" >/dev/null 2>&1 & fi
BASH
chmod 0755 /usr/local/bin/nexos-settings-report
cat > /usr/local/bin/nexos-startup-manager <<'PY'
#!/usr/bin/env python3
import os, subprocess, tkinter as tk
from pathlib import Path
from tkinter import ttk, messagebox
USER=Path.home()/'.config'/'autostart'; SYSTEM=Path('/etc/xdg/autostart'); USER.mkdir(parents=True,exist_ok=True)
def items():
    out=[]
    for base in (USER,SYSTEM):
        if base.exists():
            for p in sorted(base.glob('*.desktop')): out.append(p)
    return out
def toggle(p):
    txt=p.read_text(errors='ignore')
    if 'Hidden=true' in txt: txt=txt.replace('Hidden=true','Hidden=false')
    elif 'Hidden=false' in txt: txt=txt.replace('Hidden=false','Hidden=true')
    else: txt += '\nHidden=true\n'
    if not str(p).startswith(str(USER)):
        dest=USER/p.name; dest.write_text(txt); p=dest
    else: p.write_text(txt)
    refresh()
def refresh():
    tree.delete(*tree.get_children())
    for p in items():
        txt=p.read_text(errors='ignore'); name=p.stem; hidden='Hidden=true' in txt
        for line in txt.splitlines():
            if line.startswith('Name='): name=line.split('=',1)[1]
        tree.insert('', 'end', values=('Disabled' if hidden else 'Enabled', name, str(p)))
r=tk.Tk(); r.title('NexOS Startup Manager'); r.geometry('900x560'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Startup Manager',bg='#07111f',fg='#e8f7ff',font=('Sans',28,'bold')).pack(anchor='w',padx=24,pady=18)
tree=ttk.Treeview(r,columns=('Status','Name','File'),show='headings'); tree.heading('Status',text='Status'); tree.heading('Name',text='Name'); tree.heading('File',text='File'); tree.pack(fill='both',expand=True,padx=18,pady=10)
def do_toggle():
    sel=tree.selection()
    if not sel: return
    toggle(Path(tree.item(sel[0],'values')[2]))
tk.Button(r,text='Enable / Disable Selected',command=do_toggle,bg='#1f2937',fg='#e8f7ff',relief='flat',padx=16,pady=10).pack(anchor='e',padx=18,pady=12)
refresh(); r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-startup-manager
cat > /usr/local/bin/nexos-privacy-center <<'PY'
#!/usr/bin/env python3
import os, shutil, subprocess, tkinter as tk
from pathlib import Path
from tkinter import ttk, messagebox
HOME=Path.home()
def clean_recent():
    for f in [HOME/'.local/share/recently-used.xbel', HOME/'.local/share/RecentDocuments']:
        try:
            if f.is_file(): f.unlink()
        except Exception: pass
    subprocess.call(['notify-send','NexOS Privacy','Recent files cleared'])
def open_cache(): subprocess.Popen(['xdg-open',str(HOME/'.cache')])
def clean_cache():
    cache=HOME/'.cache'
    if cache.exists():
        for p in cache.iterdir():
            try:
                if p.is_dir(): shutil.rmtree(p,ignore_errors=True)
                else: p.unlink()
            except Exception: pass
    subprocess.call(['notify-send','NexOS Privacy','User cache cleaned'])
r=tk.Tk(); r.title('NexOS Privacy Center'); r.geometry('720x430'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Privacy Center',bg='#07111f',fg='#e8f7ff',font=('Sans',28,'bold')).pack(anchor='w',padx=24,pady=18)
f=tk.Frame(r,bg='#07111f',padx=24); f.pack(fill='both',expand=True)
for n,c in [('Clear Recent Files',clean_recent),('Open Cache Folder',open_cache),('Clean User Cache',clean_cache)]: tk.Button(f,text=n,command=c,bg='#1f2937',fg='#e8f7ff',activebackground='#0ea5e9',relief='flat',padx=18,pady=14,font=('Sans',12,'bold')).pack(fill='x',pady=8)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-privacy-center
cat > /usr/local/bin/nexos-settings <<'PY'
#!/usr/bin/env python3
import shutil, subprocess, tkinter as tk
from tkinter import ttk, messagebox
TOOLS={
'Home':[('Control Suite','nexos-control-suite'),('Workspace Suite','nexos-workspace-suite'),('AI Assistant','nexos-assistant-toggle')],
'Display':[('Display Settings','xfce4-display-settings'),('Display Fix','nexos-display-fix'),('ARandR Layout','arandr'),('Driver Center','nexos-driver-center')],
'Sound':[('Volume Control','pavucontrol'),('Audio Detect','x-terminal-emulator -e nexos-audio-detect'),('Mixer','x-terminal-emulator -e alsamixer')],
'Input':[('Keyboard Settings','xfce4-keyboard-settings'),('Mouse Settings','xfce4-mouse-settings'),('Window Manager Keys','xfce4-keyboard-settings')],
'Appearance':[('Theme Center','nexos-theme-center'),('Appearance Settings','xfce4-appearance-settings'),('Window Manager','xfwm4-settings')],
'Network':[('Network Center','nexos-network-center'),('Network Settings','nm-connection-editor'),('Network Report','nexos-network-report')],
'Apps':[('App Installer','nexos-app-installer'),('Update Center','nexos-update-center'),('Archive Manager','nexos-archive-manager')],
'System':[('Driver Center','nexos-driver-center'),('Update Center','nexos-update-center'),('Repair Center','nexos-repair-center'),('Startup Manager','nexos-startup-manager'),('Settings Report','nexos-settings-report')],
'Privacy':[('Privacy Center','nexos-privacy-center'),('File Center','nexos-file-center')]
}
def run(c):
    e=c.split()[0]
    if shutil.which(e): subprocess.Popen(c.split(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    else: messagebox.showwarning('NexOS Settings',f'{e} is not installed in this build.')
r=tk.Tk(); r.title('NexOS Settings'); r.geometry('1040x690'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Settings',bg='#07111f',fg='#e8f7ff',font=('Sans',32,'bold')).pack(anchor='w',padx=24,pady=(20,4))
tk.Label(r,text='Display, sound, input, appearance, network, apps, updates, drivers, storage, privacy and startup.',bg='#07111f',fg='#9bd5ff',font=('Sans',12)).pack(anchor='w',padx=24,pady=(0,12))
nb=ttk.Notebook(r); nb.pack(fill='both',expand=True,padx=18,pady=14)
for cat,items in TOOLS.items():
    f=tk.Frame(nb,bg='#07111f',padx=14,pady=14); nb.add(f,text=cat)
    for i,(n,c) in enumerate(items):
        tk.Button(f,text=n,command=lambda x=c:run(x),bg='#1f2937',fg='#e8f7ff',activebackground='#0ea5e9',relief='flat',padx=14,pady=14,font=('Sans',11,'bold')).grid(row=i//2,column=i%2,padx=8,pady=8,sticky='ew'); f.grid_columnconfigure(i%2,weight=1)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-settings
for spec in "nexos-settings|NexOS Settings|Settings;System;" "nexos-startup-manager|NexOS Startup Manager|Settings;System;" "nexos-privacy-center|NexOS Privacy Center|Settings;System;" "nexos-settings-report|NexOS Settings Report|System;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-settings.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-settings' not in s: p.write_text(s.replace('\n]', '\n    ("Settings", ["nexos-settings"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('settings','nexos-settings','NexOS Settings'),('startup manager','nexos-startup-manager','NexOS Startup Manager'),('privacy center','nexos-privacy-center','NexOS Privacy Center'),('settings report','nexos-settings-report','NexOS Settings Report')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Settings:
- Adds custom settings hub for display, sound, input, appearance, network, apps, updates, drivers, startup, privacy, and reports.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/280-nexos-settings-app.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/280-nexos-settings-app.hook.chroot"
success "Injected NexOS Settings app for $NEXOS_EDITION."
