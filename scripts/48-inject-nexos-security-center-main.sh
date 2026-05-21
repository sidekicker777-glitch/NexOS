#!/usr/bin/env bash
# NexOS Security Center Main: normal-user security hub for firewall, updates, startup review, permissions, privacy cleanup and reports.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/81-nexos-security-center-main.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
ufw
gufw
procps
psmisc
util-linux
lsof
net-tools
iproute2
curl
wget
ca-certificates
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/400-nexos-security-center-main.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin ufw gufw procps psmisc util-linux lsof net-tools iproute2 curl wget ca-certificates; do install_if_available "$p"; done
mkdir -p /opt/nexos/security-center "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/.config/nexos/security-center" "$home_dir/NexOS/Reports"
cat > "$icon_dir/nexos-security-center.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#22c55e" stroke-width="4"/><path d="M64 25l38 14v29c0 25-16 43-38 52-22-9-38-27-38-52V39z" fill="none" stroke="#e8f7ff" stroke-width="7" stroke-linejoin="round"/><path d="M48 66l11 11 24-27" fill="none" stroke="#38bdf8" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/></svg>
SVG
cat > /usr/local/bin/nexos-security-status <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
echo "NexOS Security Status"
echo "===================="
echo "Firewall:"; sudo ufw status verbose 2>/dev/null | sed 's/^/  /' || echo "  ufw unavailable"
echo
echo "Updates:"; apt list --upgradable 2>/dev/null | sed 's/^/  /' | head -40 || true
echo
echo "Listening network services:"; ss -tulpn 2>/dev/null | sed 's/^/  /' | head -60 || true
echo
echo "Startup apps:"; find "$HOME/.config/autostart" /etc/xdg/autostart -maxdepth 1 -name '*.desktop' -printf '  %p\n' 2>/dev/null | head -80 || true
echo
echo "Suspicious temp executables:"; find /tmp "$HOME/Downloads" -maxdepth 2 -type f -perm -111 -printf '  %p\n' 2>/dev/null | head -60 || true
BASH
chmod 0755 /usr/local/bin/nexos-security-status
cat > /usr/local/bin/nexos-security-report <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Reports/security-report-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$out")"
{
nexos-security-status || true
echo; echo "Process overview:"; ps -eo pid,ppid,user,comm,%cpu,%mem --sort=-%cpu | head -80 || true
echo; echo "Open files/network summary:"; lsof -i -nP 2>/dev/null | head -120 || true
echo; echo "Recent auth/security logs:"; journalctl -p warning -n 160 --no-pager 2>/dev/null | grep -iE 'auth|sudo|polkit|ssh|firewall|ufw|denied|failed|permission|security' || true
echo; echo "World-writable files in NexOS data:"; find "$HOME/NexOS" -type f -perm -002 -printf '%m %p\n' 2>/dev/null | head -100 || true
echo; echo "Large downloads review:"; find "$HOME/Downloads" -type f -printf '%s %p\n' 2>/dev/null | sort -nr | head -80 | awk '{size=$1;$1=""; printf "%.2f MB %s\n", size/1024/1024, $0}' || true
} > "$out"
if command -v mousepad >/dev/null 2>&1; then mousepad "$out" >/dev/null 2>&1 & else xdg-open "$out" >/dev/null 2>&1 & fi
BASH
chmod 0755 /usr/local/bin/nexos-security-report
cat > /usr/local/bin/nexos-firewall-enable <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
sudo ufw --force enable
notify-send "NexOS Security" "Firewall enabled" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-firewall-enable
cat > /usr/local/bin/nexos-firewall-disable <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
sudo ufw disable
notify-send "NexOS Security" "Firewall disabled" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-firewall-disable
cat > /usr/local/bin/nexos-privacy-clean <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
rm -f "$HOME/.local/share/recently-used.xbel" 2>/dev/null || true
rm -rf "$HOME/.local/share/Trash/files"/* "$HOME/.local/share/Trash/info"/* 2>/dev/null || true
find "$HOME/.cache" -mindepth 1 -maxdepth 2 -type f -mtime +2 -delete 2>/dev/null || true
notify-send "NexOS Security" "Privacy cleanup complete" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-privacy-clean
cat > /usr/local/bin/nexos-permission-audit <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Reports/permission-audit-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$out")"
{
echo "NexOS Permission Audit"; echo "====================="; date; echo
echo "Executable files in Downloads:"; find "$HOME/Downloads" -type f -perm -111 -printf '%m %p\n' 2>/dev/null | head -150 || true; echo
echo "World-writable files in Home:"; find "$HOME" -path "$HOME/.cache" -prune -o -type f -perm -002 -printf '%m %p\n' 2>/dev/null | head -150 || true; echo
echo "SUID files outside system dirs:"; find "$HOME" -perm -4000 -printf '%m %p\n' 2>/dev/null || true
} > "$out"
if command -v mousepad >/dev/null 2>&1; then mousepad "$out" >/dev/null 2>&1 & else xdg-open "$out" >/dev/null 2>&1 & fi
BASH
chmod 0755 /usr/local/bin/nexos-permission-audit
cat > /usr/local/bin/nexos-security-center <<'PY'
#!/usr/bin/env python3
import shutil, subprocess, tkinter as tk
from tkinter import ttk, messagebox
A={
'Overview':[('Refresh Status','refresh'),('Security Report','nexos-security-report'),('Permission Audit','nexos-permission-audit'),('Task Manager','nexos-task-manager')],
'Firewall':[('Enable Firewall','x-terminal-emulator -e nexos-firewall-enable'),('Disable Firewall','x-terminal-emulator -e nexos-firewall-disable'),('Firewall GUI','gufw'),('Firewall Status','x-terminal-emulator -e sudo ufw status verbose')],
'Updates':[('Update Center','nexos-update-center'),('Check Updates','x-terminal-emulator -e nexos-update-check'),('Software Center','nexos-software-center')],
'Privacy':[('Privacy Cleanup','nexos-privacy-clean'),('Privacy Center','nexos-privacy-center'),('Startup Review','nexos-startup-manager'),('Backup Center','nexos-backup-restore-center')],
'Tools':[('Open Reports','xdg-open ~/NexOS/Reports'),('Action Center','nexos-action-center'),('Settings','nexos-settings')]
}
def run(c):
    if c=='refresh': refresh(); return
    e=c.split()[0]
    if shutil.which(e): subprocess.Popen(c.split(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    else: messagebox.showwarning('NexOS Security Center',f'{e} is not installed.')
def status():
    try: return subprocess.check_output(['nexos-security-status'],text=True,stderr=subprocess.DEVNULL,timeout=5)
    except Exception as e: return 'Status unavailable\n'+str(e)
def refresh():
    txt.delete('1.0','end'); txt.insert('1.0',status())
r=tk.Tk(); r.title('NexOS Security Center'); r.geometry('1040x700'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Security Center',bg='#07111f',fg='#e8f7ff',font=('Sans',31,'bold')).pack(anchor='w',padx=24,pady=(20,4))
tk.Label(r,text='Main OS security hub: firewall, updates, startup review, permissions, privacy cleanup and reports.',bg='#07111f',fg='#9bd5ff',wraplength=920,justify='left').pack(anchor='w',padx=24,pady=(0,10))
txt=tk.Text(r,height=13,bg='#0d172b',fg='#e8f7ff',insertbackground='#e8f7ff',relief='flat',font=('DejaVu Sans Mono',9)); txt.pack(fill='x',padx=24,pady=8)
nb=ttk.Notebook(r); nb.pack(fill='both',expand=True,padx=18,pady=14)
for cat,items in A.items():
    f=tk.Frame(nb,bg='#07111f',padx=14,pady=14); nb.add(f,text=cat)
    for i,(n,c) in enumerate(items): tk.Button(f,text=n,command=lambda x=c:run(x),bg='#1f2937',fg='#e8f7ff',activebackground='#0ea5e9',relief='flat',padx=14,pady=14,font=('Sans',11,'bold')).grid(row=i//2,column=i%2,padx=8,pady=8,sticky='ew'); f.grid_columnconfigure(i%2,weight=1)
refresh(); r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-security-center
for spec in "nexos-security-center|NexOS Security Center|Settings;System;Security;" "nexos-security-report|NexOS Security Report|System;Security;" "nexos-permission-audit|NexOS Permission Audit|System;Security;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-security-center.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-security-center' not in s: p.write_text(s.replace('\n]', '\n    ("Security", ["nexos-security-center"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /usr/local/bin/nexos-action-center ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-action-center'); s=p.read_text()
if "('Security','nexos-security-center')" not in s:
    s=s.replace("('Settings','nexos-settings')", "('Security','nexos-security-center'),('Settings','nexos-settings')")
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-action-center; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('security center','nexos-security-center','NexOS Security Center'),('security status','x-terminal-emulator -e nexos-security-status','NexOS Security Status'),('security report','nexos-security-report','NexOS Security Report'),('enable firewall','x-terminal-emulator -e nexos-firewall-enable','Enable Firewall'),('privacy clean','nexos-privacy-clean','Privacy Cleanup')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Security Center Main:
- Adds normal-user security hub with firewall controls, update review, startup review, permission audit, privacy cleanup, reports, dock/menu entries, Action Center integration, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/400-nexos-security-center-main.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/400-nexos-security-center-main.hook.chroot"
success "Injected NexOS Security Center Main for $NEXOS_EDITION."
