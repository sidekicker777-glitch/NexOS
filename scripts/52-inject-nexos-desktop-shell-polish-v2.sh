#!/usr/bin/env bash
# NexOS Desktop Shell Polish v2: dock/panel layout, pinned apps, trusted launchers, desktop shortcuts, icon cleanup and shell polish.
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
xfce4-panel
xfce4-settings
x11-xserver-utils
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
for p in python3 python3-tk xdg-utils libnotify-bin xfconf xfce4-panel xfce4-settings x11-xserver-utils exo-utils wmctrl; do install_if_available "$p"; done
mkdir -p /opt/nexos/desktop-shell "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/Desktop" "$home_dir/.config/autostart" "$home_dir/.config/nexos/desktop-shell" "$home_dir/NexOS/Reports"
cat > "$icon_dir/nexos-desktop-shell.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><rect x="25" y="30" width="78" height="56" rx="8" fill="none" stroke="#e8f7ff" stroke-width="7"/><rect x="34" y="94" width="60" height="10" rx="5" fill="#22c55e"/><path d="M40 45h20M40 60h36M40 75h48" stroke="#38bdf8" stroke-width="5" stroke-linecap="round"/></svg>
SVG
cat > /usr/local/bin/nexos-trust-launchers <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
for dir in "$HOME/Desktop" "$HOME/.local/share/applications" /usr/share/applications; do
  [[ -d "$dir" ]] || continue
  find "$dir" -maxdepth 1 -name 'nexos-*.desktop' -type f -print0 2>/dev/null | while IFS= read -r -d '' f; do
    chmod +x "$f" 2>/dev/null || true
    gio set "$f" metadata::trusted true 2>/dev/null || true
    if ! grep -q '^X-XFCE-Trusted=true' "$f" 2>/dev/null; then echo 'X-XFCE-Trusted=true' >> "$f"; fi
  done
done
notify-send "NexOS Desktop" "NexOS launchers trusted" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-trust-launchers
cat > /usr/local/bin/nexos-create-desktop-shortcuts <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/Desktop"
make_shortcut(){
  local name="$1" exec="$2" icon="$3" file="$HOME/Desktop/${name// /-}.desktop"
  cat > "$file" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=$icon
Terminal=false
Categories=System;
X-XFCE-Trusted=true
DESKTOP
  chmod +x "$file"; gio set "$file" metadata::trusted true 2>/dev/null || true
}
make_shortcut "NexOS Control Panel" "nexos-control-panel" "/usr/share/icons/hicolor/scalable/apps/nexos-control-panel.svg"
make_shortcut "NexOS Search" "nexos-search-center" "/usr/share/icons/hicolor/scalable/apps/nexos-search-center.svg"
make_shortcut "NexOS Settings" "nexos-settings" "/usr/share/icons/hicolor/scalable/apps/nexos-settings.svg"
make_shortcut "NexOS Software" "nexos-software-center" "/usr/share/icons/hicolor/scalable/apps/nexos-software-center.svg"
make_shortcut "NexOS Files" "nexos-file-center" "/usr/share/icons/hicolor/scalable/apps/nexos-file-center.svg"
notify-send "NexOS Desktop" "Desktop shortcuts refreshed" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-create-desktop-shortcuts
cat > /usr/local/bin/nexos-panel-polish <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
# Safer XFCE panel polish without destroying user layout.
xfconf-query -c xfce4-panel -p /panels/panel-1/position -n -t string -s 'p=10;x=0;y=0' 2>/dev/null || true
xfconf-query -c xfce4-panel -p /panels/panel-1/size -n -t int -s 36 2>/dev/null || true
xfconf-query -c xfce4-panel -p /panels/panel-1/length -n -t int -s 100 2>/dev/null || true
xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior -n -t int -s 0 2>/dev/null || true
xfconf-query -c xfwm4 -p /general/workspace_count -n -t int -s 2 2>/dev/null || true
notify-send "NexOS Desktop" "Panel layout polished" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-panel-polish
cat > /usr/local/bin/nexos-desktop-finalize <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
nexos-trust-launchers >/dev/null 2>&1 || true
nexos-create-desktop-shortcuts >/dev/null 2>&1 || true
nexos-panel-polish >/dev/null 2>&1 || true
nexos-apply-branding >/dev/null 2>&1 || true
nexos-search-index >/dev/null 2>&1 || true
notify-send "NexOS Desktop" "Desktop shell finalized" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-desktop-finalize
cat > /usr/local/bin/nexos-desktop-shell-report <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Reports/desktop-shell-report-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$out")"
{
echo "NexOS Desktop Shell Report"; echo "=========================="; date; echo
echo "Panel config:"; xfconf-query -c xfce4-panel -l -v 2>/dev/null | head -220 || true; echo
echo "Desktop launchers:"; find "$HOME/Desktop" -maxdepth 1 -name '*.desktop' -printf '%m %p\n' 2>/dev/null || true; echo
echo "NexOS app icons:"; find /usr/share/icons/hicolor/scalable/apps -maxdepth 1 -name 'nexos-*.svg' -printf '%p\n' 2>/dev/null | sort || true; echo
echo "Missing icon refs in NexOS desktop files:"; for f in /usr/share/applications/nexos-*.desktop "$HOME/Desktop"/*.desktop; do [[ -f "$f" ]] || continue; i="$(grep -m1 '^Icon=' "$f" | cut -d= -f2- || true)"; [[ -n "$i" && "$i" == /* && ! -e "$i" ]] && echo "$f -> $i"; done
} > "$out"
if command -v mousepad >/dev/null 2>&1; then mousepad "$out" >/dev/null 2>&1 & else xdg-open "$out" >/dev/null 2>&1 & fi
BASH
chmod 0755 /usr/local/bin/nexos-desktop-shell-report
cat > /usr/local/bin/nexos-desktop-shell-center <<'PY'
#!/usr/bin/env python3
import shutil, subprocess, tkinter as tk
from tkinter import ttk, messagebox
A={
'Polish':[('Finalize Desktop Shell','nexos-desktop-finalize'),('Trust NexOS Launchers','nexos-trust-launchers'),('Refresh Desktop Shortcuts','nexos-create-desktop-shortcuts'),('Polish Panel Layout','nexos-panel-polish')],
'Open':[('Control Panel','nexos-control-panel'),('Search Center','nexos-search-center'),('Personalization','nexos-personalization-center'),('Action Center','nexos-action-center')],
'Layout':[('Balanced Layout','nexos-layout-apply balanced'),('Clean Layout','nexos-layout-apply clean'),('Desktop Layout','nexos-layout-apply desktop'),('Session Modes','nexos-session-mode-switcher')],
'Reports':[('Desktop Shell Report','nexos-desktop-shell-report'),('Control Panel Report','nexos-control-panel-report'),('Personalization Report','nexos-personalization-report')]
}
def run(c):
    e=c.split()[0]
    if shutil.which(e): subprocess.Popen(c.split(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    else: messagebox.showwarning('NexOS Desktop Shell',f'{e} is not installed.')
r=tk.Tk(); r.title('NexOS Desktop Shell Center'); r.geometry('980x650'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Desktop Shell Center',bg='#07111f',fg='#e8f7ff',font=('Sans',31,'bold')).pack(anchor='w',padx=24,pady=(20,4))
tk.Label(r,text='Polish the visible desktop: trusted launchers, pinned shortcuts, panel layout, icons and NexOS shell cleanup.',bg='#07111f',fg='#9bd5ff',wraplength=900,justify='left').pack(anchor='w',padx=24,pady=(0,12))
nb=ttk.Notebook(r); nb.pack(fill='both',expand=True,padx=18,pady=14)
for cat,items in A.items():
    f=tk.Frame(nb,bg='#07111f',padx=14,pady=14); nb.add(f,text=cat)
    for i,(n,c) in enumerate(items):
        tk.Button(f,text=n,command=lambda x=c:run(x),bg='#1f2937',fg='#e8f7ff',activebackground='#0ea5e9',relief='flat',padx=14,pady=14,font=('Sans',11,'bold')).grid(row=i//2,column=i%2,padx=8,pady=8,sticky='ew')
        f.grid_columnconfigure(i%2,weight=1)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-desktop-shell-center
cat > "$home_dir/.config/autostart/nexos-desktop-shell-finalize.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Desktop Shell Finalize
Exec=nexos-desktop-finalize
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP
for spec in "nexos-desktop-shell-center|NexOS Desktop Shell Center|Settings;DesktopSettings;" "nexos-desktop-shell-report|NexOS Desktop Shell Report|System;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-desktop-shell.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-desktop-shell-center' not in s: p.write_text(s.replace('\n]', '\n    ("Desktop", ["nexos-desktop-shell-center"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /usr/local/bin/nexos-control-panel ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-control-panel'); s=p.read_text()
if 'NexOS Desktop Shell Center' not in s:
    s=s.replace('["Personalization", "nexos-personalization-center", "Wallpapers, themes, fonts and layout"],', '["Personalization", "nexos-personalization-center", "Wallpapers, themes, fonts and layout"],\n    ["Desktop Shell", "nexos-desktop-shell-center", "Panel, shortcuts and launcher cleanup"],')
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-control-panel; fi
if [[ -f /usr/local/bin/nexos-action-center ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-action-center'); s=p.read_text()
if "('Desktop','nexos-desktop-shell-center')" not in s:
    s=s.replace("('Personalize','nexos-personalization-center')", "('Desktop','nexos-desktop-shell-center'),('Personalize','nexos-personalization-center')")
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-action-center; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('desktop shell','nexos-desktop-shell-center','NexOS Desktop Shell Center'),('fix desktop','nexos-desktop-finalize','Finalize NexOS Desktop'),('trust launchers','nexos-trust-launchers','Trust NexOS Launchers'),('desktop report','nexos-desktop-shell-report','NexOS Desktop Shell Report')]:
    d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Desktop Shell Polish v2:
- Adds desktop shell center, trusted launcher cleanup, desktop shortcut refresh, panel polish, desktop finalize autostart, reports, dock/menu entries, Control Panel integration, Action Center integration, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/440-nexos-desktop-shell-polish-v2.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/440-nexos-desktop-shell-polish-v2.hook.chroot"
success "Injected NexOS Desktop Shell Polish v2 for $NEXOS_EDITION."
