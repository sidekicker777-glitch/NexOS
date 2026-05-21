#!/usr/bin/env bash
# NexOS Network Center v2: Wi-Fi/network settings, IP/DNS status, ping/speed checks, adapter report, and quick network tools.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/82-nexos-network-center-v2.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
network-manager
network-manager-gnome
wireless-tools
wpasupplicant
rfkill
iproute2
net-tools
dnsutils
inetutils-ping
traceroute
curl
wget
ca-certificates
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/410-nexos-network-center-v2.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin network-manager network-manager-gnome wireless-tools wpasupplicant rfkill iproute2 net-tools dnsutils inetutils-ping traceroute curl wget ca-certificates; do install_if_available "$p"; done
mkdir -p /opt/nexos/network-center "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/.config/nexos/network-center" "$home_dir/NexOS/Reports"
cat > "$icon_dir/nexos-network-center.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><path d="M29 55c21-18 49-18 70 0M43 70c12-10 30-10 42 0M57 85c4-4 10-4 14 0" fill="none" stroke="#e8f7ff" stroke-width="8" stroke-linecap="round"/><circle cx="64" cy="99" r="7" fill="#22c55e"/></svg>
SVG
cat > /usr/local/bin/nexos-network-status <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
echo "NexOS Network Status"
echo "===================="
echo "NetworkManager:"; nmcli general status 2>/dev/null | sed 's/^/  /' || echo "  nmcli unavailable"
echo
echo "Devices:"; nmcli device status 2>/dev/null | sed 's/^/  /' || ip -brief link | sed 's/^/  /'
echo
echo "IP addresses:"; ip -brief addr 2>/dev/null | sed 's/^/  /' || true
echo
echo "Routes:"; ip route 2>/dev/null | sed 's/^/  /' || true
echo
echo "DNS:"; resolvectl status 2>/dev/null | sed -n '1,80p' | sed 's/^/  /' || cat /etc/resolv.conf 2>/dev/null | sed 's/^/  /' || true
echo
echo "Wi-Fi/radio:"; rfkill list 2>/dev/null | sed 's/^/  /' || true; iwconfig 2>/dev/null | sed 's/^/  /' || true
BASH
chmod 0755 /usr/local/bin/nexos-network-status
cat > /usr/local/bin/nexos-network-report <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Reports/network-report-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$out")"
{
nexos-network-status || true
echo; echo "Adapters:"; lspci -nnk 2>/dev/null | grep -EA4 'Network|Ethernet|Wireless' || true; echo; lsusb 2>/dev/null | grep -Ei 'network|wireless|bluetooth|wifi|ethernet|802.11' || true
echo; echo "Connectivity checks:"; ping -c 4 1.1.1.1 2>&1 || true; echo; ping -c 4 google.com 2>&1 || true
echo; echo "Traceroute:"; traceroute -m 8 1.1.1.1 2>&1 || true
echo; echo "Listening services:"; ss -tulpn 2>/dev/null || true
echo; echo "Firewall:"; sudo ufw status verbose 2>/dev/null || true
} > "$out"
if command -v mousepad >/dev/null 2>&1; then mousepad "$out" >/dev/null 2>&1 & else xdg-open "$out" >/dev/null 2>&1 & fi
BASH
chmod 0755 /usr/local/bin/nexos-network-report
cat > /usr/local/bin/nexos-ping-check <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
target="${1:-1.1.1.1}"
echo "NexOS Ping Check: $target"
echo "======================"
ping -c 6 "$target"
echo; echo "Press Enter to close"; read -r _ || true
BASH
chmod 0755 /usr/local/bin/nexos-ping-check
cat > /usr/local/bin/nexos-dns-check <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
domain="${1:-google.com}"
echo "NexOS DNS Check: $domain"
echo "====================="
nslookup "$domain" 2>/dev/null || dig "$domain" 2>/dev/null || host "$domain" 2>/dev/null || true
echo; echo "Press Enter to close"; read -r _ || true
BASH
chmod 0755 /usr/local/bin/nexos-dns-check
cat > /usr/local/bin/nexos-network-speed-check <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
echo "NexOS Basic Download Check"
echo "=========================="
echo "Downloading small test file from Cloudflare CDN..."
bytes="$(curl -L --max-time 15 -o /dev/null -w '%{size_download}' https://speed.cloudflare.com/__down?bytes=5000000 2>/dev/null || echo 0)"
time="$(curl -L --max-time 15 -o /dev/null -w '%{time_total}' https://speed.cloudflare.com/__down?bytes=1000000 2>/dev/null || echo 0)"
echo "Downloaded bytes sample: $bytes"
echo "Second timing sample: $time seconds"
echo "For full testing, install speedtest-cli from Software Center if available."
echo; echo "Press Enter to close"; read -r _ || true
BASH
chmod 0755 /usr/local/bin/nexos-network-speed-check
cat > /usr/local/bin/nexos-network-reset-soft <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
sudo systemctl restart NetworkManager || sudo service NetworkManager restart || true
notify-send "NexOS Network" "NetworkManager restarted" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-network-reset-soft
cat > /usr/local/bin/nexos-network-center <<'PY'
#!/usr/bin/env python3
import shutil, subprocess, tkinter as tk
from tkinter import ttk, messagebox, simpledialog
A={
'Overview':[('Refresh Status','refresh'),('Network Report','nexos-network-report'),('Adapter / Driver Report','nexos-wifi-detect'),('Driver Center','nexos-driver-center')],
'Settings':[('Wi-Fi / Network Settings','nm-connection-editor'),('NetworkManager TUI','x-terminal-emulator -e nmtui'),('Restart NetworkManager','x-terminal-emulator -e nexos-network-reset-soft'),('Radio / RFKill Status','x-terminal-emulator -e rfkill list')],
'Tests':[('Ping 1.1.1.1','x-terminal-emulator -e nexos-ping-check 1.1.1.1'),('Ping Google','x-terminal-emulator -e nexos-ping-check google.com'),('DNS Check','x-terminal-emulator -e nexos-dns-check google.com'),('Basic Speed Check','x-terminal-emulator -e nexos-network-speed-check')],
'Security':[('Security Center','nexos-security-center'),('Firewall Status','x-terminal-emulator -e sudo ufw status verbose'),('Enable Firewall','x-terminal-emulator -e nexos-firewall-enable'),('Listening Services','x-terminal-emulator -e ss -tulpn')],
'Tools':[('Action Center','nexos-action-center'),('Settings','nexos-settings'),('Open Reports','xdg-open ~/NexOS/Reports')]
}
def run(c):
    if c=='refresh': refresh(); return
    e=c.split()[0]
    if shutil.which(e): subprocess.Popen(c.split(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    else: messagebox.showwarning('NexOS Network Center',f'{e} is not installed.')
def status():
    try: return subprocess.check_output(['nexos-network-status'],text=True,stderr=subprocess.DEVNULL,timeout=5)
    except Exception as e: return 'Network status unavailable\n'+str(e)
def refresh():
    txt.delete('1.0','end'); txt.insert('1.0',status())
def custom_ping():
    t=simpledialog.askstring('Ping target','Host or IP to ping:',initialvalue='1.1.1.1')
    if t: run('x-terminal-emulator -e nexos-ping-check '+t)
r=tk.Tk(); r.title('NexOS Network Center'); r.geometry('1040x720'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Network Center',bg='#07111f',fg='#e8f7ff',font=('Sans',31,'bold')).pack(anchor='w',padx=24,pady=(20,4))
tk.Label(r,text='Wi-Fi, IP, DNS, adapters, ping checks, speed checks, firewall shortcuts, and network reports.',bg='#07111f',fg='#9bd5ff',wraplength=920,justify='left').pack(anchor='w',padx=24,pady=(0,10))
txt=tk.Text(r,height=14,bg='#0d172b',fg='#e8f7ff',insertbackground='#e8f7ff',relief='flat',font=('DejaVu Sans Mono',9)); txt.pack(fill='x',padx=24,pady=8)
quick=tk.Frame(r,bg='#07111f'); quick.pack(fill='x',padx=24,pady=4)
tk.Button(quick,text='Custom Ping',command=custom_ping,bg='#0ea5e9',fg='white',relief='flat',padx=12,pady=8).pack(side='left',padx=4)
nb=ttk.Notebook(r); nb.pack(fill='both',expand=True,padx=18,pady=14)
for cat,items in A.items():
    f=tk.Frame(nb,bg='#07111f',padx=14,pady=14); nb.add(f,text=cat)
    for i,(n,c) in enumerate(items): tk.Button(f,text=n,command=lambda x=c:run(x),bg='#1f2937',fg='#e8f7ff',activebackground='#0ea5e9',relief='flat',padx=14,pady=14,font=('Sans',11,'bold')).grid(row=i//2,column=i%2,padx=8,pady=8,sticky='ew'); f.grid_columnconfigure(i%2,weight=1)
refresh(); r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-network-center
for spec in "nexos-network-center|NexOS Network Center|Settings;System;Network;" "nexos-network-report|NexOS Network Report|System;Network;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-network-center.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-network-center' not in s: p.write_text(s.replace('\n]', '\n    ("Network", ["nexos-network-center"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /usr/local/bin/nexos-action-center ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-action-center'); s=p.read_text()
if "('Network Center','nexos-network-center')" not in s:
    s=s.replace("('Wi-Fi / Network','nm-connection-editor')", "('Wi-Fi / Network','nm-connection-editor'),('Network Center','nexos-network-center')")
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-action-center; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('network center','nexos-network-center','NexOS Network Center'),('network status','x-terminal-emulator -e nexos-network-status','NexOS Network Status'),('network report','nexos-network-report','NexOS Network Report'),('ping check','x-terminal-emulator -e nexos-ping-check','Ping Check'),('dns check','x-terminal-emulator -e nexos-dns-check','DNS Check')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Network Center v2:
- Adds network status, Wi-Fi/settings tools, IP/DNS checks, ping/speed checks, adapter reports, firewall/security shortcuts, dock/menu entries, Action Center integration, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/410-nexos-network-center-v2.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/410-nexos-network-center-v2.hook.chroot"
success "Injected NexOS Network Center v2 for $NEXOS_EDITION."
