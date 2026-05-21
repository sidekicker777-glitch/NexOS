#!/usr/bin/env bash
# NexOS Action Center: notification/action panel with quick settings and system status.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/76-nexos-action-center.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
xfconf
x11-xserver-utils
network-manager-gnome
pulseaudio-utils
acpi
procps
util-linux
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/350-nexos-action-center.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin xfconf x11-xserver-utils network-manager-gnome pulseaudio-utils acpi procps util-linux; do install_if_available "$p"; done
mkdir -p /opt/nexos/action-center "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/.config/nexos/action-center" "$home_dir/NexOS/Reports"
cat > "$icon_dir/nexos-action-center.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><path d="M38 34h52a8 8 0 0 1 8 8v44a8 8 0 0 1-8 8H56l-18 14V94h-2a8 8 0 0 1-8-8V42a8 8 0 0 1 10-8z" fill="none" stroke="#e8f7ff" stroke-width="7" stroke-linejoin="round"/><circle cx="51" cy="64" r="5" fill="#22c55e"/><circle cx="67" cy="64" r="5" fill="#22c55e"/><circle cx="83" cy="64" r="5" fill="#22c55e"/></svg>
SVG
cat > /usr/local/bin/nexos-action-status <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
echo "NexOS Quick Status"
echo "=================="
echo "Mode: $(nexos-mode-current 2>/dev/null || echo desktop)"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p 2>/dev/null || true)"
echo "Memory:"; free -h | awk '/Mem:/ {print "  Used "$3" / "$2}'
echo "Disk:"; df -h / | awk 'NR==2 {print "  Used "$3" / "$2" ("$5")"}'
echo "Network:"; ip -brief addr 2>/dev/null | sed 's/^/  /' || true
echo "Audio:"; pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | head -1 | sed 's/^/  /' || true
echo "Battery:"; acpi -b 2>/dev/null | sed 's/^/  /' || echo "  not detected"
BASH
chmod 0755 /usr/local/bin/nexos-action-status
cat > /usr/local/bin/nexos-action-report <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Reports/action-center-report-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$out")"
{
nexos-action-status || true
echo; echo "Recent journal warnings:"; journalctl -p warning -n 80 --no-pager 2>/dev/null || true
echo; echo "NexOS tools:"; ls /usr/local/bin/nexos-* 2>/dev/null || true
} > "$out"
if command -v mousepad >/dev/null 2>&1; then mousepad "$out" >/dev/null 2>&1 & else xdg-open "$out" >/dev/null 2>&1 & fi
BASH
chmod 0755 /usr/local/bin/nexos-action-report
cat > /usr/local/bin/nexos-toggle-panel-autohide <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
current="$(xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior 2>/dev/null || echo 0)"
if [[ "$current" == "0" ]]; then new=1; else new=0; fi
xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior -n -t int -s "$new" 2>/dev/null || true
notify-send "NexOS Action Center" "Panel autohide: $new" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-toggle-panel-autohide
cat > /usr/local/bin/nexos-action-center <<'PY'
#!/usr/bin/env python3
import shutil, subprocess, tkinter as tk
from pathlib import Path
from tkinter import messagebox
WIDTH=430
ACTIONS=[
('Wi-Fi / Network','nm-connection-editor'),('Sound','pavucontrol'),('Display','xfce4-display-settings'),('Drivers','nexos-driver-center'),
('Updates','nexos-update-center'),('Session Mode','nexos-session-mode-switcher'),('Assistant','nexos-assistant-toggle'),('Settings','nexos-settings'),
('Software','nexos-software-center'),('Files','nexos-file-center'),('Code','nexos-code-editor'),('Gaming','nexos-gaming-center'),
('Panel Autohide','nexos-toggle-panel-autohide'),('Report','nexos-action-report')]
def run(cmd):
    e=cmd.split()[0]
    if shutil.which(e): subprocess.Popen(cmd.split(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    else: messagebox.showwarning('NexOS Action Center',f'{e} is not installed.')
def status():
    try: return subprocess.check_output(['nexos-action-status'],text=True,stderr=subprocess.DEVNULL,timeout=3)
    except Exception as e: return 'Status unavailable\n'+str(e)
def refresh():
    txt.delete('1.0','end'); txt.insert('1.0',status())
r=tk.Tk(); r.title('NexOS Action Center'); r.geometry(f'{WIDTH}x760+40+40'); r.configure(bg='#07111f'); r.attributes('-topmost', True)
tk.Label(r,text='NexOS Action Center',bg='#07111f',fg='#e8f7ff',font=('Sans',24,'bold')).pack(anchor='w',padx=18,pady=(16,4))
tk.Label(r,text='Quick actions, system status, notifications, and controls.',bg='#07111f',fg='#9bd5ff',wraplength=390,justify='left').pack(anchor='w',padx=18,pady=(0,12))
txt=tk.Text(r,height=10,bg='#0d172b',fg='#e8f7ff',insertbackground='#e8f7ff',relief='flat',font=('DejaVu Sans Mono',9)); txt.pack(fill='x',padx=18,pady=8); refresh()
bar=tk.Frame(r,bg='#07111f'); bar.pack(fill='x',padx=18)
tk.Button(bar,text='Refresh',command=refresh,bg='#0ea5e9',fg='white',relief='flat',padx=12,pady=8).pack(side='left')
tk.Button(bar,text='Close',command=r.destroy,bg='#1f2937',fg='#e8f7ff',relief='flat',padx=12,pady=8).pack(side='right')
wrap=tk.Frame(r,bg='#07111f',padx=14,pady=14); wrap.pack(fill='both',expand=True)
for i,(name,cmd) in enumerate(ACTIONS):
    tk.Button(wrap,text=name,command=lambda c=cmd:run(c),bg='#1f2937',fg='#e8f7ff',activebackground='#0ea5e9',relief='flat',padx=10,pady=12,font=('Sans',10,'bold')).grid(row=i//2,column=i%2,padx=5,pady=5,sticky='ew')
    wrap.grid_columnconfigure(i%2,weight=1)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-action-center
cat > /usr/local/bin/nexos-action-center-toggle <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
if pgrep -f "python3 .*nexos-action-center" >/dev/null 2>&1; then
  pkill -f "python3 .*nexos-action-center" || true
else
  nexos-action-center >/dev/null 2>&1 &
fi
BASH
chmod 0755 /usr/local/bin/nexos-action-center-toggle
for spec in "nexos-action-center|NexOS Action Center|Settings;System;" "nexos-action-report|NexOS Action Report|System;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-action-center.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-action-center-toggle' not in s: p.write_text(s.replace('\n]', '\n    ("Actions", ["nexos-action-center-toggle"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('action center','nexos-action-center','NexOS Action Center'),('quick settings','nexos-action-center','NexOS Action Center'),('system status','x-terminal-emulator -e nexos-action-status','NexOS System Status'),('action report','nexos-action-report','NexOS Action Report')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Action Center:
- Adds quick action panel, status view, report generator, panel autohide toggle, dock/menu entries, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/350-nexos-action-center.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/350-nexos-action-center.hook.chroot"
success "Injected NexOS Action Center for $NEXOS_EDITION."
