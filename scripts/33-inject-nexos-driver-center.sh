#!/usr/bin/env bash
# NexOS Driver Center: hardware detection, GPU/audio/network/VM driver helpers, reports.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/66-nexos-driver-center.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
pciutils
usbutils
lshw
hwinfo
mesa-utils
vulkan-tools
alsa-utils
pulseaudio-utils
wireless-tools
rfkill
firmware-linux-free
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/250-nexos-driver-center.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin pciutils usbutils lshw hwinfo mesa-utils vulkan-tools alsa-utils pulseaudio-utils wireless-tools rfkill firmware-linux-free virtualbox-guest-x11 virtualbox-guest-utils xserver-xorg-video-vmware xserver-xorg-video-qxl; do install_if_available "$p"; done
mkdir -p /opt/nexos/driver-center "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/NexOS/Reports" "$home_dir/.config/nexos/driver-center"
cat > "$icon_dir/nexos-driver-center.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#a78bfa" stroke-width="4"/><rect x="31" y="40" width="66" height="48" rx="8" fill="none" stroke="#38bdf8" stroke-width="7"/><path d="M45 88v13M58 88v13M71 88v13M84 88v13M97 55h13M97 73h13M18 55h13M18 73h13" stroke="#e8f7ff" stroke-width="5" stroke-linecap="round"/><circle cx="64" cy="64" r="10" fill="#22c55e"/></svg>
SVG
cat > /usr/local/bin/nexos-driver-report <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Reports/driver-report-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$out")"
{
echo "NexOS Driver Report"; echo "==================="; date; echo
echo "Kernel:"; uname -a; echo
echo "PCI devices:"; lspci -nnk 2>/dev/null || true; echo
echo "USB devices:"; lsusb 2>/dev/null || true; echo
echo "Graphics/OpenGL:"; glxinfo -B 2>/dev/null || true; echo
echo "Vulkan:"; vulkaninfo --summary 2>/dev/null || true; echo
echo "Audio devices:"; aplay -l 2>/dev/null || true; pactl list short sinks 2>/dev/null || true; echo
echo "Network/Wireless:"; ip link 2>/dev/null || true; iwconfig 2>/dev/null || true; rfkill list 2>/dev/null || true; echo
echo "Loaded modules:"; lsmod 2>/dev/null | head -200 || true; echo
echo "Firmware messages:"; dmesg 2>/dev/null | grep -iE 'firmware|gpu|wifi|bluetooth|audio|nvidia|amd|intel|virtualbox|vmware' | tail -200 || true
} > "$out"
if command -v mousepad >/dev/null 2>&1; then mousepad "$out" >/dev/null 2>&1 & else xdg-open "$out" >/dev/null 2>&1 & fi
BASH
chmod 0755 /usr/local/bin/nexos-driver-report
cat > /usr/local/bin/nexos-gpu-detect <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
echo "NexOS GPU Detection"
echo "===================="
lspci -nnk | grep -EA4 'VGA|3D|Display' || true
echo
echo "OpenGL renderer:"
glxinfo -B 2>/dev/null | grep -E 'OpenGL vendor|OpenGL renderer|OpenGL version' || true
echo
echo "Vulkan summary:"
vulkaninfo --summary 2>/dev/null || true
echo; echo "Press Enter to close"; read -r _ || true
BASH
chmod 0755 /usr/local/bin/nexos-gpu-detect
cat > /usr/local/bin/nexos-audio-detect <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
echo "NexOS Audio Detection"
echo "====================="
aplay -l 2>/dev/null || true
echo
pactl list short sinks 2>/dev/null || true
echo
pactl list short sources 2>/dev/null || true
echo; echo "Press Enter to close"; read -r _ || true
BASH
chmod 0755 /usr/local/bin/nexos-audio-detect
cat > /usr/local/bin/nexos-wifi-detect <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
echo "NexOS Wi-Fi/Bluetooth Detection"
echo "==============================="
lspci -nnk | grep -EA4 'Network|Wireless|Bluetooth' || true
lsusb | grep -Ei 'wireless|bluetooth|wifi|802.11' || true
rfkill list 2>/dev/null || true
iwconfig 2>/dev/null || true
echo; echo "Press Enter to close"; read -r _ || true
BASH
chmod 0755 /usr/local/bin/nexos-wifi-detect
cat > /usr/local/bin/nexos-vm-driver-help <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
cat <<'TXT'
NexOS VM Driver Help
====================
VirtualBox:
- Enable Display > Graphics Controller: VMSVGA
- Enable 3D Acceleration if stable
- Install Guest Additions packages if available: virtualbox-guest-x11 virtualbox-guest-utils
- Use View > Auto-resize Guest Display

VMware:
- Use open-vm-tools/open-vm-tools-desktop when available.

QEMU/SPICE:
- Use spice-vdagent and qxl/virtio display where available.

Run nexos-display-fix after changing VM display settings.
TXT
echo; echo "Press Enter to close"; read -r _ || true
BASH
chmod 0755 /usr/local/bin/nexos-vm-driver-help
cat > /usr/local/bin/nexos-driver-center <<'PY'
#!/usr/bin/env python3
import shutil, subprocess, tkinter as tk
from tkinter import ttk, messagebox
A={'Overview':[('Full Driver Report','nexos-driver-report'),('Hardware Summary','x-terminal-emulator -e lshw -short'),('PCI Devices','x-terminal-emulator -e lspci -nnk'),('USB Devices','x-terminal-emulator -e lsusb')],'Graphics':[('GPU Detect','x-terminal-emulator -e nexos-gpu-detect'),('Display Settings','xfce4-display-settings'),('VM Driver Help','x-terminal-emulator -e nexos-vm-driver-help'),('Display Fix','nexos-display-fix')],'Audio':[('Audio Detect','x-terminal-emulator -e nexos-audio-detect'),('PulseAudio Volume','pavucontrol'),('Mixer','x-terminal-emulator -e alsamixer')],'Network':[('Wi-Fi Detect','x-terminal-emulator -e nexos-wifi-detect'),('Network Center','nexos-network-center'),('Network Settings','nm-connection-editor')]}
def run(c):
    e=c.split()[0]
    if shutil.which(e): subprocess.Popen(c.split(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    else: messagebox.showwarning('NexOS Driver Center',f'{e} is not installed.')
r=tk.Tk(); r.title('NexOS Driver Center'); r.geometry('980x650'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Driver Center',bg='#07111f',fg='#e8f7ff',font=('Sans',30,'bold')).pack(anchor='w',padx=24,pady=18)
nb=ttk.Notebook(r); nb.pack(fill='both',expand=True,padx=18,pady=14)
for cat,items in A.items():
    f=tk.Frame(nb,bg='#07111f',padx=14,pady=14); nb.add(f,text=cat)
    for i,(n,c) in enumerate(items): tk.Button(f,text=n,command=lambda x=c:run(x),bg='#1f2937',fg='#e8f7ff',activebackground='#0ea5e9',relief='flat',padx=14,pady=14,font=('Sans',11,'bold')).grid(row=i//2,column=i%2,padx=8,pady=8,sticky='ew'); f.grid_columnconfigure(i%2,weight=1)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-driver-center
for spec in "nexos-driver-center|NexOS Driver Center|System;Settings;" "nexos-driver-report|NexOS Driver Report|System;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-driver-center.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-driver-center' not in s: p.write_text(s.replace('\n]', '\n    ("Drivers", ["nexos-driver-center"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('driver center','nexos-driver-center','NexOS Driver Center'),('driver report','nexos-driver-report','NexOS Driver Report'),('gpu detect','x-terminal-emulator -e nexos-gpu-detect','NexOS GPU Detect'),('wifi detect','x-terminal-emulator -e nexos-wifi-detect','NexOS Wi-Fi Detect')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Driver Center:
- Adds GPU/audio/Wi-Fi/USB/PCI detection, VM driver help, driver reports, dock/menu entries, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/250-nexos-driver-center.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/250-nexos-driver-center.hook.chroot"
success "Injected NexOS Driver Center for $NEXOS_EDITION."
