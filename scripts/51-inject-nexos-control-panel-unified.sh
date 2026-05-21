#!/usr/bin/env bash
# NexOS Unified Control Panel: one main launcher for all NexOS hubs and system tools.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/84-nexos-control-panel-unified.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
procps
util-linux
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/430-nexos-control-panel-unified.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin procps util-linux; do install_if_available "$p"; done
mkdir -p /opt/nexos/control-panel "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/.config/nexos/control-panel" "$home_dir/NexOS/Reports"
cat > "$icon_dir/nexos-control-panel.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><rect x="29" y="31" width="28" height="28" rx="7" fill="none" stroke="#e8f7ff" stroke-width="6"/><rect x="71" y="31" width="28" height="28" rx="7" fill="none" stroke="#22c55e" stroke-width="6"/><rect x="29" y="73" width="28" height="28" rx="7" fill="none" stroke="#22c55e" stroke-width="6"/><rect x="71" y="73" width="28" height="28" rx="7" fill="none" stroke="#e8f7ff" stroke-width="6"/></svg>
SVG
cat > /opt/nexos/control-panel/catalog.json <<'JSON'
{
  "Core": [
    ["Settings", "nexos-settings", "Main NexOS settings hub"],
    ["Action Center", "nexos-action-center", "Quick settings and status"],
    ["Search Center", "nexos-search-center", "Apps, files and commands"],
    ["Power Center", "nexos-power-center", "Shutdown, restart, battery and power modes"]
  ],
  "Look and Feel": [
    ["Personalization", "nexos-personalization-center", "Wallpapers, themes, fonts and layout"],
    ["Branding Center", "nexos-branding-center", "NexOS identity and desktop branding"],
    ["Boot Branding", "nexos-boot-branding-center", "GRUB and boot splash branding"],
    ["Session Modes", "nexos-session-mode-switcher", "Desktop, gaming and console modes"]
  ],
  "System": [
    ["Task Manager", "nexos-task-manager", "Processes and system monitor"],
    ["Driver Center", "nexos-driver-center", "GPU, audio, Wi-Fi and VM drivers"],
    ["Update Center", "nexos-update-center", "Updates and repair tools"],
    ["Install Center", "nexos-install-center", "Install NexOS and post-install setup"]
  ],
  "Network and Security": [
    ["Network Center", "nexos-network-center", "Wi-Fi, DNS, IP and network tests"],
    ["Security Center", "nexos-security-center", "Firewall, privacy and audits"],
    ["Backup Center", "nexos-backup-restore-center", "Backup and restore tools"],
    ["Privacy Center", "nexos-privacy-center", "Recent files and cache cleanup"]
  ],
  "Apps and Work": [
    ["Software Center", "nexos-software-center", "Open-source app installer"],
    ["File Center", "nexos-file-center", "Files, folders and reports"],
    ["Archive Manager", "nexos-archive-manager", "ZIP/7Z/TAR extraction and creation"],
    ["Code Editor", "nexos-code-editor", "VS Code-style editor"]
  ],
  "Gaming and AI": [
    ["Game Library", "nexos-game-library", "Gaming and emulator library"],
    ["Gaming Center", "nexos-gaming-center", "Gaming shortcuts and tools"],
    ["AI Assistant", "nexos-assistant-toggle", "NexOS assistant orb/dashboard"],
    ["First-Run Wizard", "nexos-first-run-wizard", "Rerun welcome setup"]
  ]
}
JSON
cat > /usr/local/bin/nexos-control-panel-report <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Reports/control-panel-report-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$out")"
{
echo "NexOS Unified Control Panel Report"; echo "=================================="; date; echo
echo "NexOS tools:"; ls /usr/local/bin/nexos-* 2>/dev/null | sort || true; echo
echo "Desktop entries:"; ls /usr/share/applications/nexos-*.desktop 2>/dev/null | sort || true; echo
echo "Control catalog:"; sed -n '1,240p' /opt/nexos/control-panel/catalog.json 2>/dev/null || true; echo
echo "Release:"; sed -n '1,80p' /usr/share/nexos/nexos-release 2>/dev/null || true
} > "$out"
if command -v mousepad >/dev/null 2>&1; then mousepad "$out" >/dev/null 2>&1 & else xdg-open "$out" >/dev/null 2>&1 & fi
BASH
chmod 0755 /usr/local/bin/nexos-control-panel-report
cat > /usr/local/bin/nexos-control-panel <<'PY'
#!/usr/bin/env python3
import json, shutil, subprocess, tkinter as tk
from pathlib import Path
from tkinter import ttk, messagebox
CAT=Path('/opt/nexos/control-panel/catalog.json')
try: DATA=json.loads(CAT.read_text())
except Exception:
    DATA={'Core':[['Settings','nexos-settings','Main settings'],['Action Center','nexos-action-center','Quick actions']]}
def available(cmd):
    first=cmd.split()[0]
    return shutil.which(first) is not None
def run(cmd):
    first=cmd.split()[0]
    if shutil.which(first): subprocess.Popen(cmd.split(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    else: messagebox.showwarning('NexOS Control Panel',f'{first} is not installed in this build yet.')
def refresh_status():
    total=sum(len(v) for v in DATA.values())
    ok=sum(1 for items in DATA.values() for _name,cmd,_desc in items if available(cmd))
    status.config(text=f'{ok}/{total} tools available in this build')
def add_cards(parent, items):
    for i,(name,cmd,desc) in enumerate(items):
        card=tk.Frame(parent,bg='#0d172b',padx=14,pady=12,highlightbackground='#294866',highlightthickness=1)
        card.grid(row=i//2,column=i%2,padx=8,pady=8,sticky='nsew')
        parent.grid_columnconfigure(i%2,weight=1)
        tk.Label(card,text=name,bg='#0d172b',fg='#e8f7ff',font=('Sans',15,'bold')).pack(anchor='w')
        tk.Label(card,text=desc,bg='#0d172b',fg='#9bd5ff',wraplength=410,justify='left').pack(anchor='w',pady=(3,9))
        state='normal' if available(cmd) else 'disabled'
        txt='Open' if state=='normal' else 'Missing'
        tk.Button(card,text=txt,command=lambda c=cmd:run(c),state=state,bg='#0ea5e9' if state=='normal' else '#374151',fg='white',relief='flat',padx=14,pady=8).pack(anchor='e')
def search():
    q=search_var.get().strip().lower()
    for w in results.winfo_children(): w.destroy()
    if not q: return
    matches=[]
    for cat,items in DATA.items():
        for row in items:
            hay=' '.join(row+[cat]).lower()
            if q in hay: matches.append(row)
    add_cards(results,matches[:20])
r=tk.Tk(); r.title('NexOS Control Panel'); r.geometry('1120x760'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Control Panel',bg='#07111f',fg='#e8f7ff',font=('Sans',34,'bold')).pack(anchor='w',padx=24,pady=(20,4))
tk.Label(r,text='One place for every NexOS hub: settings, system, network, security, apps, gaming, AI and personalization.',bg='#07111f',fg='#9bd5ff',wraplength=1020,justify='left').pack(anchor='w',padx=24,pady=(0,10))
bar=tk.Frame(r,bg='#07111f'); bar.pack(fill='x',padx=24,pady=6)
search_var=tk.StringVar(); ent=tk.Entry(bar,textvariable=search_var,bg='#0d172b',fg='#e8f7ff',insertbackground='#38bdf8',relief='flat',font=('Sans',14)); ent.pack(side='left',fill='x',expand=True,ipady=8)
tk.Button(bar,text='Search',command=search,bg='#0ea5e9',fg='white',relief='flat',padx=14,pady=8).pack(side='left',padx=6)
tk.Button(bar,text='Report',command=lambda:run('nexos-control-panel-report'),bg='#1f2937',fg='#e8f7ff',relief='flat',padx=14,pady=8).pack(side='left')
status=tk.Label(r,text='',bg='#07111f',fg='#86efac',font=('Sans',11,'bold')); status.pack(anchor='w',padx=24,pady=(0,6)); refresh_status()
nb=ttk.Notebook(r); nb.pack(fill='both',expand=True,padx=18,pady=12)
search_tab=tk.Frame(nb,bg='#07111f',padx=14,pady=14); nb.add(search_tab,text='Search Results')
results=tk.Frame(search_tab,bg='#07111f'); results.pack(fill='both',expand=True)
for cat,items in DATA.items():
    f=tk.Frame(nb,bg='#07111f',padx=14,pady=14); nb.add(f,text=cat); add_cards(f,items)
ent.bind('<Return>',lambda e:search()); r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-control-panel
cat > /usr/local/bin/nexos-control-center <<'BASH'
#!/usr/bin/env bash
nexos-control-panel "$@"
BASH
chmod 0755 /usr/local/bin/nexos-control-center
for spec in "nexos-control-panel|NexOS Control Panel|Settings;System;" "nexos-control-panel-report|NexOS Control Panel Report|System;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-control-panel.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-control-panel' not in s:
    # Put unified control panel near the end so it always exists even when older Control Suite is present.
    p.write_text(s.replace('\n]', '\n    ("Control", ["nexos-control-panel"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /usr/local/bin/nexos-action-center ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-action-center'); s=p.read_text()
if "('Control Panel','nexos-control-panel')" not in s:
    s=s.replace("('Settings','nexos-settings')", "('Control Panel','nexos-control-panel'),('Settings','nexos-settings')")
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-action-center; fi
if [[ -f /usr/local/bin/nexos-settings ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-settings'); s=p.read_text()
if "('Control Panel','nexos-control-panel')" not in s:
    s=s.replace("'Home':[", "'Home':[('Control Panel','nexos-control-panel'),", 1)
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-settings; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('control panel','nexos-control-panel','NexOS Control Panel'),('control center','nexos-control-panel','NexOS Control Panel'),('all settings','nexos-control-panel','NexOS Control Panel'),('control panel report','nexos-control-panel-report','NexOS Control Panel Report')]:
    d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Unified Control Panel:
- Adds one main launcher for Settings, Personalization, Network, Security, Power, Updates, Drivers, Backup, Task Manager, Software Center, Search, Gaming, AI Assistant, Install Center, reports, dock/menu entries, Action Center integration, Settings integration, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/430-nexos-control-panel-unified.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/430-nexos-control-panel-unified.hook.chroot"
success "Injected NexOS Unified Control Panel for $NEXOS_EDITION."
