#!/usr/bin/env bash
# NexOS Power Center: power actions, battery status, lock/logout/reboot/shutdown, performance profile helpers.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/77-nexos-power-center.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
acpi
upower
xfce4-power-manager
xfce4-screensaver
light-locker
policykit-1
procps
util-linux
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/360-nexos-power-center.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin acpi upower xfce4-power-manager xfce4-screensaver light-locker policykit-1 procps util-linux; do install_if_available "$p"; done
mkdir -p /opt/nexos/power-center "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/.config/nexos/power-center" "$home_dir/NexOS/Reports"
cat > "$icon_dir/nexos-power-center.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#22c55e" stroke-width="4"/><path d="M64 30v36" stroke="#e8f7ff" stroke-width="10" stroke-linecap="round"/><path d="M44 44a34 34 0 1 0 40 0" fill="none" stroke="#38bdf8" stroke-width="9" stroke-linecap="round"/></svg>
SVG
cat > /usr/local/bin/nexos-power-status <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
echo "NexOS Power Status"
echo "=================="
echo "Uptime: $(uptime -p 2>/dev/null || true)"
echo "Load: $(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null || true)"
echo "Battery:"; acpi -b 2>/dev/null | sed 's/^/  /' || echo "  not detected"
echo "AC adapter:"; acpi -a 2>/dev/null | sed 's/^/  /' || true
echo "UPower:"; upower -e 2>/dev/null | sed 's/^/  /' || true
echo "Memory:"; free -h | awk '/Mem:/ {print "  Used "$3" / "$2}'
echo "Session:"; loginctl show-session "${XDG_SESSION_ID:-}" -p Type -p State -p Remote 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-power-status
cat > /usr/local/bin/nexos-power-report <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Reports/power-report-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$out")"
{
nexos-power-status || true
echo; echo "Power devices:"; upower -d 2>/dev/null || true
echo; echo "XFCE power settings:"; xfconf-query -c xfce4-power-manager -l -v 2>/dev/null || true
echo; echo "Recent power logs:"; journalctl -b --no-pager 2>/dev/null | grep -iE 'power|battery|suspend|hibernate|shutdown|reboot|sleep' | tail -120 || true
} > "$out"
if command -v mousepad >/dev/null 2>&1; then mousepad "$out" >/dev/null 2>&1 & else xdg-open "$out" >/dev/null 2>&1 & fi
BASH
chmod 0755 /usr/local/bin/nexos-power-report
cat > /usr/local/bin/nexos-lock-screen <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
if command -v xflock4 >/dev/null 2>&1; then xflock4; elif command -v light-locker-command >/dev/null 2>&1; then light-locker-command -l; elif command -v loginctl >/dev/null 2>&1; then loginctl lock-session; fi
BASH
chmod 0755 /usr/local/bin/nexos-lock-screen
cat > /usr/local/bin/nexos-logout-session <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
if command -v xfce4-session-logout >/dev/null 2>&1; then xfce4-session-logout --logout; else loginctl terminate-session "${XDG_SESSION_ID:-}"; fi
BASH
chmod 0755 /usr/local/bin/nexos-logout-session
cat > /usr/local/bin/nexos-suspend-system <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
systemctl suspend
BASH
chmod 0755 /usr/local/bin/nexos-suspend-system
cat > /usr/local/bin/nexos-restart-system <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
systemctl reboot
BASH
chmod 0755 /usr/local/bin/nexos-restart-system
cat > /usr/local/bin/nexos-shutdown-system <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
systemctl poweroff
BASH
chmod 0755 /usr/local/bin/nexos-shutdown-system
cat > /usr/local/bin/nexos-set-power-mode <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
mode="${1:-balanced}"
mkdir -p "$HOME/.config/nexos/power-center"
echo "$mode" > "$HOME/.config/nexos/power-center/mode"
case "$mode" in
 performance)
  if command -v powerprofilesctl >/dev/null 2>&1; then powerprofilesctl set performance 2>/dev/null || true; fi
  ;;
 balanced)
  if command -v powerprofilesctl >/dev/null 2>&1; then powerprofilesctl set balanced 2>/dev/null || true; fi
  ;;
 saver|powersave)
  if command -v powerprofilesctl >/dev/null 2>&1; then powerprofilesctl set power-saver 2>/dev/null || true; fi
  ;;
 *) echo "Usage: nexos-set-power-mode performance|balanced|saver"; exit 1;;
esac
notify-send "NexOS Power Center" "Power mode set to $mode" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-set-power-mode
cat > /usr/local/bin/nexos-power-center <<'PY'
#!/usr/bin/env python3
import shutil, subprocess, tkinter as tk
from tkinter import messagebox
ACTIONS=[
('Lock Screen','nexos-lock-screen','#1f2937'),('Log Out','nexos-logout-session','#1f2937'),('Suspend','nexos-suspend-system','#365314'),('Restart','nexos-restart-system','#92400e'),('Shutdown','nexos-shutdown-system','#7f1d1d')]
TOOLS=[('Power Settings','xfce4-power-manager-settings'),('Power Report','nexos-power-report'),('Action Center','nexos-action-center'),('Settings','nexos-settings')]
def run(c):
    e=c.split()[0]
    if shutil.which(e): subprocess.Popen(c.split(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    else: messagebox.showwarning('NexOS Power Center',f'{e} is not installed.')
def status():
    try: return subprocess.check_output(['nexos-power-status'],text=True,stderr=subprocess.DEVNULL,timeout=3)
    except Exception as e: return 'Status unavailable\n'+str(e)
def refresh():
    txt.delete('1.0','end'); txt.insert('1.0',status())
def confirm(name,cmd):
    if name in ('Restart','Shutdown','Log Out','Suspend'):
        if not messagebox.askyesno('NexOS Power Center',f'{name} now?'): return
    run(cmd)
r=tk.Tk(); r.title('NexOS Power Center'); r.geometry('860x620'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Power Center',bg='#07111f',fg='#e8f7ff',font=('Sans',30,'bold')).pack(anchor='w',padx=24,pady=(20,4))
tk.Label(r,text='Power actions, battery status, performance modes, lock, logout, restart and shutdown.',bg='#07111f',fg='#9bd5ff').pack(anchor='w',padx=24,pady=(0,12))
txt=tk.Text(r,height=9,bg='#0d172b',fg='#e8f7ff',insertbackground='#e8f7ff',relief='flat',font=('DejaVu Sans Mono',9)); txt.pack(fill='x',padx=24,pady=8); refresh()
f=tk.Frame(r,bg='#07111f',padx=20); f.pack(fill='both',expand=True)
for i,(n,c,color) in enumerate(ACTIONS):
    tk.Button(f,text=n,command=lambda a=n,x=c:confirm(a,x),bg=color,fg='#e8f7ff',activebackground='#0ea5e9',relief='flat',padx=16,pady=16,font=('Sans',12,'bold')).grid(row=0,column=i,padx=5,pady=8,sticky='ew'); f.grid_columnconfigure(i,weight=1)
mode=tk.LabelFrame(f,text='Power Modes',bg='#07111f',fg='#9bd5ff',padx=10,pady=10); mode.grid(row=1,column=0,columnspan=5,sticky='ew',pady=10)
for i,(n,m) in enumerate([('Performance','performance'),('Balanced','balanced'),('Power Saver','saver')]): tk.Button(mode,text=n,command=lambda x=m:run('nexos-set-power-mode '+x),bg='#1f2937',fg='#e8f7ff',relief='flat',padx=14,pady=10).grid(row=0,column=i,padx=5,sticky='ew'); mode.grid_columnconfigure(i,weight=1)
tools=tk.Frame(f,bg='#07111f'); tools.grid(row=2,column=0,columnspan=5,sticky='ew',pady=8)
for i,(n,c) in enumerate(TOOLS+[('Refresh Status','refresh')]):
    cmd=(refresh if c=='refresh' else lambda x=c:run(x))
    tk.Button(tools,text=n,command=cmd,bg='#1f2937',fg='#e8f7ff',relief='flat',padx=14,pady=10).grid(row=0,column=i,padx=5,sticky='ew'); tools.grid_columnconfigure(i,weight=1)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-power-center
for spec in "nexos-power-center|NexOS Power Center|Settings;System;" "nexos-power-report|NexOS Power Report|System;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-power-center.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-power-center' not in s: p.write_text(s.replace('\n]', '\n    ("Power", ["nexos-power-center"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /usr/local/bin/nexos-action-center ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-action-center'); s=p.read_text()
if "('Power','nexos-power-center')" not in s:
    s=s.replace("('Panel Autohide','nexos-toggle-panel-autohide')", "('Power','nexos-power-center'),('Panel Autohide','nexos-toggle-panel-autohide')")
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-action-center; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('power center','nexos-power-center','NexOS Power Center'),('power status','x-terminal-emulator -e nexos-power-status','NexOS Power Status'),('lock screen','nexos-lock-screen','Lock Screen'),('suspend','nexos-suspend-system','Suspend System'),('restart system','nexos-restart-system','Restart System'),('shutdown system','nexos-shutdown-system','Shutdown System')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Power Center:
- Adds power status, battery report, lock/logout/suspend/restart/shutdown helpers, performance mode helper, dock/menu entries, Action Center integration, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/360-nexos-power-center.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/360-nexos-power-center.hook.chroot"
success "Injected NexOS Power Center for $NEXOS_EDITION."
