#!/usr/bin/env bash
# NexOS Desktop Shell Polish v2: desktop shortcuts, launcher trust, panel/dock helpers, icon cleanup, right-click helper menu.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/85-nexos-desktop-shell-polish-v2.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
xfconf
xfce4-settings
xfce4-panel
thunar
mousepad
hicolor-icon-theme
exo-utils
wmctrl
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/440-nexos-desktop-shell-polish-v2.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin xfconf xfce4-settings xfce4-panel thunar mousepad hicolor-icon-theme exo-utils wmctrl; do install_if_available "$p"; done
mkdir -p /opt/nexos/shell-polish "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/Desktop" "$home_dir/.config/nexos/shell" "$home_dir/.config/autostart" "$home_dir/NexOS/Reports"
cat > "$icon_dir/nexos-shell-polish.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><rect x="26" y="30" width="76" height="54" rx="8" fill="none" stroke="#e8f7ff" stroke-width="7"/><path d="M26 91h76" stroke="#22c55e" stroke-width="8" stroke-linecap="round"/><path d="M42 45h44M42 61h28" stroke="#38bdf8" stroke-width="6" stroke-linecap="round"/></svg>
SVG
cat > /usr/local/bin/nexos-trust-launchers <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
for d in "$HOME/Desktop" "$HOME/.local/share/applications" /usr/share/applications; do
  [[ -d "$d" ]] || continue
  find "$d" -maxdepth 1 -name 'nexos-*.desktop' -type f -exec chmod 0755 {} \; 2>/dev/null || true
  find "$d" -maxdepth 1 -name 'nexos-*.desktop' -type f -exec gio set {} metadata::trusted true \; 2>/dev/null || true
done
notify-send "NexOS Desktop" "Launchers trusted" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-trust-launchers
cat > /usr/local/bin/nexos-create-desktop-shortcuts <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/Desktop"
apps=(nexos-control-panel nexos-search-center nexos-action-center nexos-settings nexos-personalization-center nexos-file-center nexos-code-editor nexos-software-center nexos-power-center)
for app in "${apps[@]}"; do
  src="/usr/share/applications/$app.desktop"
  [[ -f "$src" ]] || continue
  cp "$src" "$HOME/Desktop/$app.desktop"
  chmod 0755 "$HOME/Desktop/$app.desktop"
  gio set "$HOME/Desktop/$app.desktop" metadata::trusted true 2>/dev/null || true
done
notify-send "NexOS Desktop" "Desktop shortcuts created" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-create-desktop-shortcuts
cat > /usr/local/bin/nexos-panel-layout-apply <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
layout="${1:-nexos}"
mkdir -p "$HOME/.config/nexos/shell"
echo "$layout" > "$HOME/.config/nexos/shell/panel-layout"
case "$layout" in
 nexos)
  xfconf-query -c xfce4-panel -p /panels/panel-1/position -n -t string -s 'p=10;x=0;y=0' 2>/dev/null || true
  xfconf-query -c xfce4-panel -p /panels/panel-1/length -n -t uint -s 100 2>/dev/null || true
  xfconf-query -c xfce4-panel -p /panels/panel-1/size -n -t uint -s 36 2>/dev/null || true
  xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior -n -t int -s 0 2>/dev/null || true
  ;;
 clean)
  xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior -n -t int -s 1 2>/dev/null || true
  ;;
 classic)
  xfconf-query -c xfce4-panel -p /panels/panel-1/position -n -t string -s 'p=6;x=0;y=0' 2>/dev/null || true
  xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior -n -t int -s 0 2>/dev/null || true
  ;;
 *) echo "Usage: nexos-panel-layout-apply nexos|clean|classic"; exit 1;;
esac
notify-send "NexOS Desktop" "Panel layout applied: $layout" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-panel-layout-apply
cat > /usr/local/bin/nexos-clean-desktop-icons <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/Desktop/.hidden-by-nexos"
for f in "$HOME/Desktop"/*.desktop; do
  [[ -f "$f" ]] || continue
  b="$(basename "$f")"
  case "$b" in
    debian-*.desktop|install-debian*.desktop|xfce4-*.desktop)
      mv "$f" "$HOME/Desktop/.hidden-by-nexos/$b" 2>/dev/null || true
      ;;
  esac
done
nexos-trust-launchers >/dev/null 2>&1 || true
notify-send "NexOS Desktop" "Desktop icon cleanup complete" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-clean-desktop-icons
cat > /usr/local/bin/nexos-shell-report <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Reports/shell-report-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$out")"
{
echo "NexOS Desktop Shell Report"; echo "=========================="; date; echo
echo "Desktop launchers:"; find "$HOME/Desktop" -maxdepth 2 -type f -printf '%m %p\n' 2>/dev/null | sort || true; echo
echo "Panel settings:"; xfconf-query -c xfce4-panel -l -v 2>/dev/null | head -250 || true; echo
echo "Desktop settings:"; xfconf-query -c xfce4-desktop -l -v 2>/dev/null | head -250 || true; echo
echo "NexOS desktop entries:"; ls /usr/share/applications/nexos-*.desktop 2>/dev/null | sort || true
} > "$out"
if command -v mousepad >/dev/null 2>&1; then mousepad "$out" >/dev/null 2>&1 & else xdg-open "$out" >/dev/null 2>&1 & fi
BASH
chmod 0755 /usr/local/bin/nexos-shell-report
cat > /usr/local/bin/nexos-desktop-finalize <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
nexos-apply-branding >/dev/null 2>&1 || true
nexos-theme-apply dark >/dev/null 2>&1 || true
nexos-panel-layout-apply nexos >/dev/null 2>&1 || true
nexos-create-desktop-shortcuts >/dev/null 2>&1 || true
nexos-clean-desktop-icons >/dev/null 2>&1 || true
notify-send "NexOS Desktop" "Desktop finalized" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-desktop-finalize
cat > /usr/local/bin/nexos-desktop-shell-center <<'PY'
#!/usr/bin/env python3
import shutil, subprocess, tkinter as tk
from tkinter import ttk, messagebox
A={
'Finish Desktop':[('Finalize NexOS Desktop','nexos-desktop-finalize'),('Create Desktop Shortcuts','nexos-create-desktop-shortcuts'),('Trust Launchers','nexos-trust-launchers'),('Clean Duplicate Icons','nexos-clean-desktop-icons')],
'Panel Layouts':[('NexOS Layout','nexos-panel-layout-apply nexos'),('Clean Autohide Layout','nexos-panel-layout-apply clean'),('Classic Bottom Layout','nexos-panel-layout-apply classic'),('Panel Preferences','xfce4-panel --preferences')],
'Shortcuts':[('Control Panel','nexos-control-panel'),('Search Center','nexos-search-center'),('Action Center','nexos-action-center'),('Personalization','nexos-personalization-center')],
'Troubleshooting':[('Shell Report','nexos-shell-report'),('Restart Panel','xfce4-panel -r'),('Open Desktop Folder','xdg-open ~/Desktop'),('Open Hidden Icons','xdg-open ~/Desktop/.hidden-by-nexos')]
}
def run(c):
    e=c.split()[0]
    if shutil.which(e): subprocess.Popen(c.split(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    else: messagebox.showwarning('NexOS Desktop Shell',f'{e} is not installed.')
r=tk.Tk(); r.title('NexOS Desktop Shell Center'); r.geometry('980x650'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Desktop Shell Center',bg='#07111f',fg='#e8f7ff',font=('Sans',31,'bold')).pack(anchor='w',padx=24,pady=(20,4))
tk.Label(r,text='Polish the visible desktop: shortcuts, launcher trust, panel layout, icon cleanup and shell reports.',bg='#07111f',fg='#9bd5ff',wraplength=900,justify='left').pack(anchor='w',padx=24,pady=(0,10))
nb=ttk.Notebook(r); nb.pack(fill='both',expand=True,padx=18,pady=14)
for cat,items in A.items():
    f=tk.Frame(nb,bg='#07111f',padx=14,pady=14); nb.add(f,text=cat)
    for i,(n,c) in enumerate(items): tk.Button(f,text=n,command=lambda x=c:run(x),bg='#1f2937',fg='#e8f7ff',activebackground='#0ea5e9',relief='flat',padx=14,pady=14,font=('Sans',11,'bold')).grid(row=i//2,column=i%2,padx=8,pady=8,sticky='ew'); f.grid_columnconfigure(i%2,weight=1)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-desktop-shell-center
for spec in "nexos-desktop-shell-center|NexOS Desktop Shell Center|Settings;DesktopSettings;" "nexos-shell-report|NexOS Shell Report|System;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-shell-polish.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
cat > "$home_dir/.config/autostart/nexos-desktop-finalize.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Desktop Finalize
Exec=sh -c 'test -f "$HOME/.config/nexos/shell/finalized" || (nexos-desktop-finalize && mkdir -p "$HOME/.config/nexos/shell" && touch "$HOME/.config/nexos/shell/finalized")'
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-desktop-shell-center' not in s: p.write_text(s.replace('\n]', '\n    ("Desktop", ["nexos-desktop-shell-center"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /usr/local/bin/nexos-action-center ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-action-center'); s=p.read_text()
if "('Desktop','nexos-desktop-shell-center')" not in s:
    s=s.replace("('Personalize','nexos-personalization-center')", "('Desktop','nexos-desktop-shell-center'),('Personalize','nexos-personalization-center')")
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-action-center; fi
if [[ -f /usr/local/bin/nexos-control-panel ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-control-panel'); s=p.read_text()
needle='["Personalization", "nexos-personalization-center", "Wallpapers, themes, fonts and layout"]'
if 'nexos-desktop-shell-center' not in s:
    s=s.replace(needle, needle + ',\n    ["Desktop Shell", "nexos-desktop-shell-center", "Shortcuts, panels and launcher polish"]')
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-control-panel; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('desktop shell','nexos-desktop-shell-center','NexOS Desktop Shell Center'),('finalize desktop','nexos-desktop-finalize','Finalize NexOS Desktop'),('trust launchers','nexos-trust-launchers','Trust Launchers'),('shell report','nexos-shell-report','NexOS Shell Report')]:
    d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Desktop Shell Polish v2:
- Adds desktop shortcut creation, launcher trust fixes, icon cleanup, panel layout profiles, desktop finalize, shell report, dock/menu entries, Action Center integration, Control Panel integration, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/440-nexos-desktop-shell-polish-v2.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/440-nexos-desktop-shell-polish-v2.hook.chroot"
success "Injected NexOS Desktop Shell Polish v2 for $NEXOS_EDITION."
