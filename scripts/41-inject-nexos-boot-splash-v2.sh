#!/usr/bin/env bash
# NexOS Boot Splash / GRUB Branding v2: GRUB labels, splash assets, Plymouth theme, boot docs.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
EDITION_LABEL="${EDITION_LABEL:-NexOS Main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/74-nexos-boot-splash-v2.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
imagemagick
plymouth
plymouth-themes
grub-common
grub-pc-bin
grub-efi-amd64-bin
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/330-nexos-boot-splash-v2.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
EDITION_LABEL="__EDITION_LABEL__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin imagemagick plymouth plymouth-themes grub-common grub-pc-bin grub-efi-amd64-bin; do install_if_available "$p"; done
mkdir -p /opt/nexos/boot-splash "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos /usr/share/backgrounds/nexos /usr/share/plymouth/themes/nexos /boot/grub
cat > "$icon_dir/nexos-boot-splash.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><path d="M64 29c19 13 29 29 29 46 0 16-13 29-29 29S35 91 35 75c0-17 10-33 29-46z" fill="none" stroke="#22c55e" stroke-width="8"/><path d="M54 78h20M64 55v31" stroke="#e8f7ff" stroke-width="7" stroke-linecap="round"/></svg>
SVG
if command -v convert >/dev/null 2>&1; then
  convert -size 1920x1080 gradient:'#020617-#0f172a' \
    -fill 'rgba(56,189,248,0.18)' -draw 'circle 1470,290 1820,290' \
    -fill 'rgba(34,197,94,0.12)' -draw 'circle 430,790 760,790' \
    -fill '#e8f7ff' -gravity center -pointsize 92 -font DejaVu-Sans-Bold -annotate +0-30 'NexOS' \
    -fill '#7dd3fc' -gravity center -pointsize 28 -font DejaVu-Sans -annotate +0+48 'Starting your workspace' \
    /usr/share/backgrounds/nexos/nexos-boot-v2.png || true
  convert /usr/share/backgrounds/nexos/nexos-boot-v2.png -resize 1024x768^ -gravity center -extent 1024x768 /boot/grub/nexos-grub.png || true
  convert -size 256x256 xc:transparent -fill '#38bdf8' -draw 'circle 128,128 128,28' -fill '#020617' -draw 'circle 128,128 128,55' -fill '#e8f7ff' -gravity center -pointsize 42 -font DejaVu-Sans-Bold -annotate +0+7 'N' /usr/share/plymouth/themes/nexos/nexos-logo.png || true
fi
cat > /usr/share/plymouth/themes/nexos/nexos.plymouth <<'PLY'
[Plymouth Theme]
Name=NexOS
Description=NexOS boot splash
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/nexos
ScriptFile=/usr/share/plymouth/themes/nexos/nexos.script
PLY
cat > /usr/share/plymouth/themes/nexos/nexos.script <<'PLY'
Window.SetBackgroundTopColor(0.02, 0.04, 0.10);
Window.SetBackgroundBottomColor(0.02, 0.08, 0.14);
logo = Image("nexos-logo.png");
sprite = Sprite(logo);
sprite.SetX(Window.GetWidth()/2 - logo.GetWidth()/2);
sprite.SetY(Window.GetHeight()/2 - logo.GetHeight()/2 - 40);
message = Sprite();
fun refresh_callback(){
  text = Image.Text("NexOS", 1, 1, 1);
  message.SetImage(text);
  message.SetX(Window.GetWidth()/2 - text.GetWidth()/2);
  message.SetY(Window.GetHeight()/2 + 110);
}
Plymouth.SetRefreshFunction(refresh_callback);
PLY
cat > /etc/default/grub.d/60-nexos-branding.cfg <<'GRUB'
GRUB_DISTRIBUTOR="NexOS"
GRUB_THEME=""
GRUB_BACKGROUND="/boot/grub/nexos-grub.png"
GRUB_TIMEOUT=5
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_DISABLE_OS_PROBER=false
GRUB
cat > /usr/local/bin/nexos-boot-report <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Reports/boot-report-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$out")"
{
echo "NexOS Boot Branding Report"; echo "==========================="; date; echo
echo "Boot mode:"; if [[ -d /sys/firmware/efi ]]; then echo UEFI; else echo Legacy BIOS; fi; echo
echo "GRUB defaults:"; sed -n '1,160p' /etc/default/grub 2>/dev/null || true; echo; sed -n '1,160p' /etc/default/grub.d/60-nexos-branding.cfg 2>/dev/null || true; echo
echo "Plymouth themes:"; plymouth-set-default-theme --list 2>/dev/null || true; echo
echo "Boot assets:"; ls -lah /boot/grub/nexos-grub.png /usr/share/backgrounds/nexos/nexos-boot-v2.png /usr/share/plymouth/themes/nexos 2>/dev/null || true
} > "$out"
if command -v mousepad >/dev/null 2>&1; then mousepad "$out" >/dev/null 2>&1 & else xdg-open "$out" >/dev/null 2>&1 & fi
BASH
chmod 0755 /usr/local/bin/nexos-boot-report
cat > /usr/local/bin/nexos-apply-boot-branding <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  sudo plymouth-set-default-theme nexos -R 2>/dev/null || sudo plymouth-set-default-theme nexos 2>/dev/null || true
fi
if command -v update-grub >/dev/null 2>&1; then sudo update-grub || true; fi
notify-send "NexOS Boot" "Boot branding applied" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-apply-boot-branding
cat > /usr/local/bin/nexos-boot-branding-center <<'PY'
#!/usr/bin/env python3
import shutil, subprocess, tkinter as tk
from tkinter import messagebox
A=[('Apply Boot Branding','x-terminal-emulator -e nexos-apply-boot-branding'),('Boot Report','nexos-boot-report'),('Open Boot Assets','xdg-open /usr/share/backgrounds/nexos'),('Open Branding Center','nexos-branding-center'),('Open Install Center','nexos-install-center')]
def run(c):
    e=c.split()[0]
    if shutil.which(e): subprocess.Popen(c.split(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    else: messagebox.showwarning('NexOS Boot Branding',f'{e} is not installed.')
r=tk.Tk(); r.title('NexOS Boot Branding Center'); r.geometry('790x480'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Boot Branding Center',bg='#07111f',fg='#e8f7ff',font=('Sans',29,'bold')).pack(anchor='w',padx=24,pady=18)
tk.Label(r,text='GRUB labels, boot background, Plymouth theme, reports, and boot branding tools.',bg='#07111f',fg='#9bd5ff').pack(anchor='w',padx=24,pady=(0,14))
f=tk.Frame(r,bg='#07111f',padx=22); f.pack(fill='both',expand=True)
for n,c in A: tk.Button(f,text=n,command=lambda x=c:run(x),bg='#1f2937',fg='#e8f7ff',activebackground='#0ea5e9',relief='flat',padx=18,pady=13,font=('Sans',12,'bold')).pack(fill='x',pady=6)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-boot-branding-center
cat > /usr/share/applications/nexos-boot-branding-center.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Boot Branding Center
Exec=nexos-boot-branding-center
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-boot-splash.svg
Terminal=false
Categories=Settings;System;
X-XFCE-Trusted=true
DESKTOP
chmod 0755 /usr/share/applications/nexos-boot-branding-center.desktop
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-boot-branding-center' not in s: p.write_text(s.replace('\n]', '\n    ("Boot", ["nexos-boot-branding-center"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('boot branding','nexos-boot-branding-center','NexOS Boot Branding Center'),('boot report','nexos-boot-report','NexOS Boot Report'),('apply boot branding','x-terminal-emulator -e nexos-apply-boot-branding','NexOS Apply Boot Branding')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Boot Splash / GRUB Branding v2:
- Adds boot splash art, GRUB distributor/background config, Plymouth theme, boot report, apply helper, dock/menu entries, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" -e "s/__EDITION_LABEL__/$EDITION_LABEL/g" "$LB_CONFIG_DIR/hooks/normal/330-nexos-boot-splash-v2.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/330-nexos-boot-splash-v2.hook.chroot"
success "Injected NexOS Boot Splash v2 for $NEXOS_EDITION."
