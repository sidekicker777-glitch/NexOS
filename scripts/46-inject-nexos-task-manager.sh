#!/usr/bin/env bash
# NexOS Task Manager: system monitor, process viewer/killer, startup and resource reports.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/79-nexos-task-manager.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
procps
psmisc
util-linux
sysstat
lsof
htop
iotop
nethogs
xfce4-taskmanager
gnome-system-monitor
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/380-nexos-task-manager.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin procps psmisc util-linux sysstat lsof htop iotop nethogs xfce4-taskmanager gnome-system-monitor; do install_if_available "$p"; done
mkdir -p /opt/nexos/task-manager "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/.config/nexos/task-manager" "$home_dir/NexOS/Reports"
cat > "$icon_dir/nexos-task-manager.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><path d="M30 88h68" stroke="#e8f7ff" stroke-width="7" stroke-linecap="round"/><path d="M37 78V52M55 78V38M73 78V61M91 78V45" stroke="#22c55e" stroke-width="9" stroke-linecap="round"/><path d="M31 33h66" stroke="#60a5fa" stroke-width="6" stroke-linecap="round"/></svg>
SVG
cat > /usr/local/bin/nexos-system-status <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
echo "NexOS System Status"
echo "==================="
echo "Uptime: $(uptime -p 2>/dev/null || true)"
echo "Load: $(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null || true)"
echo "CPU:"; top -bn1 | awk '/Cpu\(s\)|%Cpu/ {print "  "$0; exit}' || true
echo "Memory:"; free -h | awk '/Mem:/ {print "  Used "$3" / "$2" (free "$4")"}'
echo "Swap:"; free -h | awk '/Swap:/ {print "  Used "$3" / "$2}'
echo "Disk /:"; df -h / | awk 'NR==2 {print "  Used "$3" / "$2" ("$5")"}'
echo "Top CPU processes:"; ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -8 | sed 's/^/  /'
echo "Top RAM processes:"; ps -eo pid,comm,%cpu,%mem --sort=-%mem | head -8 | sed 's/^/  /'
BASH
chmod 0755 /usr/local/bin/nexos-system-status
cat > /usr/local/bin/nexos-task-report <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Reports/task-manager-report-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$out")"
{
nexos-system-status || true
echo; echo "All processes by CPU:"; ps -eo pid,ppid,user,comm,%cpu,%mem --sort=-%cpu | head -80 || true
echo; echo "All processes by RAM:"; ps -eo pid,ppid,user,comm,%cpu,%mem --sort=-%mem | head -80 || true
echo; echo "Open listening ports:"; ss -tulpn 2>/dev/null || true
echo; echo "Open files summary:"; lsof -nP 2>/dev/null | head -120 || true
echo; echo "Startup apps:"; find "$HOME/.config/autostart" /etc/xdg/autostart -maxdepth 1 -name '*.desktop' -printf '%p\n' 2>/dev/null || true
echo; echo "Journal warnings:"; journalctl -p warning -n 120 --no-pager 2>/dev/null || true
} > "$out"
if command -v mousepad >/dev/null 2>&1; then mousepad "$out" >/dev/null 2>&1 & else xdg-open "$out" >/dev/null 2>&1 & fi
BASH
chmod 0755 /usr/local/bin/nexos-task-report
cat > /usr/local/bin/nexos-kill-process <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
pid="${1:-}"
[[ "$pid" =~ ^[0-9]+$ ]] || { echo "Usage: nexos-kill-process <pid>"; exit 1; }
kill "$pid" 2>/dev/null || sudo kill "$pid"
notify-send "NexOS Task Manager" "Killed process $pid" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-kill-process
cat > /usr/local/bin/nexos-task-manager <<'PY'
#!/usr/bin/env python3
import os, signal, shutil, subprocess, tkinter as tk
from tkinter import ttk, messagebox, simpledialog
COLS=('pid','user','name','cpu','mem')
def get_status():
    try: return subprocess.check_output(['nexos-system-status'],text=True,stderr=subprocess.DEVNULL,timeout=3)
    except Exception as e: return 'Status unavailable\n'+str(e)
def get_processes():
    out=subprocess.check_output(['ps','-eo','pid,user,comm,%cpu,%mem','--sort=-%cpu'],text=True,stderr=subprocess.DEVNULL)
    rows=[]
    for line in out.splitlines()[1:250]:
        parts=line.split(None,4)
        if len(parts)==5: rows.append(parts)
    return rows
def run(cmd):
    e=cmd.split()[0]
    if shutil.which(e): subprocess.Popen(cmd.split(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    else: messagebox.showwarning('NexOS Task Manager',f'{e} is not installed.')
def refresh():
    txt.delete('1.0','end'); txt.insert('1.0',get_status())
    tree.delete(*tree.get_children())
    q=filter_var.get().strip().lower()
    for pid,user,name,cpu,mem in get_processes():
        if q and q not in (pid+' '+user+' '+name).lower(): continue
        tree.insert('', 'end', values=(pid,user,name,cpu,mem))
def kill_selected():
    sel=tree.selection()
    if not sel: return
    vals=tree.item(sel[0],'values'); pid=vals[0]; name=vals[2]
    if not messagebox.askyesno('NexOS Task Manager',f'Kill {name} ({pid})?'): return
    try: os.kill(int(pid), signal.SIGTERM)
    except Exception:
        subprocess.call(['nexos-kill-process',str(pid)])
    refresh()
def force_kill():
    pid=simpledialog.askstring('Force kill','PID to kill:')
    if not pid: return
    subprocess.call(['nexos-kill-process',pid]); refresh()
r=tk.Tk(); r.title('NexOS Task Manager'); r.geometry('1080x720'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Task Manager',bg='#07111f',fg='#e8f7ff',font=('Sans',30,'bold')).pack(anchor='w',padx=24,pady=(20,4))
tk.Label(r,text='System monitor, process manager, startup/resource tools and reports.',bg='#07111f',fg='#9bd5ff').pack(anchor='w',padx=24,pady=(0,10))
txt=tk.Text(r,height=9,bg='#0d172b',fg='#e8f7ff',insertbackground='#e8f7ff',relief='flat',font=('DejaVu Sans Mono',9)); txt.pack(fill='x',padx=24,pady=8)
bar=tk.Frame(r,bg='#07111f'); bar.pack(fill='x',padx=24,pady=5)
filter_var=tk.StringVar(); tk.Entry(bar,textvariable=filter_var,bg='#0d172b',fg='#e8f7ff',insertbackground='#38bdf8',relief='flat').pack(side='left',fill='x',expand=True,ipady=8); filter_var.trace_add('write',lambda *_:refresh())
for n,c in [('Refresh',refresh),('Kill Selected',kill_selected),('Force Kill PID',force_kill),('Report',lambda:run('nexos-task-report')),('Startup',lambda:run('nexos-startup-manager'))]:
    tk.Button(bar,text=n,command=c,bg='#0ea5e9' if n=='Refresh' else '#1f2937',fg='white' if n=='Refresh' else '#e8f7ff',relief='flat',padx=12,pady=8).pack(side='left',padx=4)
frame=tk.Frame(r,bg='#07111f'); frame.pack(fill='both',expand=True,padx=24,pady=12)
tree=ttk.Treeview(frame,columns=COLS,show='headings')
for c,t,w in [('pid','PID',80),('user','User',140),('name','Process',340),('cpu','CPU %',90),('mem','RAM %',90)]: tree.heading(c,text=t); tree.column(c,width=w,anchor='w')
ys=tk.Scrollbar(frame,command=tree.yview); tree.configure(yscrollcommand=ys.set); tree.pack(side='left',fill='both',expand=True); ys.pack(side='right',fill='y')
quick=tk.Frame(r,bg='#07111f'); quick.pack(fill='x',padx=24,pady=(0,16))
for n,c in [('HTop','x-terminal-emulator -e htop'),('XFCE Task Manager','xfce4-taskmanager'),('System Monitor','gnome-system-monitor'),('Action Center','nexos-action-center'),('Power Center','nexos-power-center')]: tk.Button(quick,text=n,command=lambda x=c:run(x),bg='#1f2937',fg='#e8f7ff',relief='flat',padx=12,pady=8).pack(side='left',padx=4)
refresh(); r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-task-manager
for spec in "nexos-task-manager|NexOS Task Manager|System;Monitor;" "nexos-task-report|NexOS Task Report|System;Monitor;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-task-manager.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-task-manager' not in s: p.write_text(s.replace('\n]', '\n    ("Tasks", ["nexos-task-manager"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /usr/local/bin/nexos-action-center ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-action-center'); s=p.read_text()
if "('Task Manager','nexos-task-manager')" not in s:
    s=s.replace("('Power','nexos-power-center')", "('Task Manager','nexos-task-manager'),('Power','nexos-power-center')")
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-action-center; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('task manager','nexos-task-manager','NexOS Task Manager'),('system monitor','nexos-task-manager','NexOS Task Manager'),('system status','x-terminal-emulator -e nexos-system-status','NexOS System Status'),('task report','nexos-task-report','NexOS Task Report')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Task Manager:
- Adds system monitor, process list/filter, kill helpers, resource reports, startup links, dock/menu entries, Action Center integration, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/380-nexos-task-manager.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/380-nexos-task-manager.hook.chroot"
success "Injected NexOS Task Manager for $NEXOS_EDITION."
