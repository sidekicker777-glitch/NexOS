#!/usr/bin/env bash
# NexOS Session Mode Switcher: Desktop Mode / Console-Gaming Mode startup profile tools.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/75-nexos-session-mode-switcher.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
xfconf
x11-xserver-utils
wmctrl
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/340-nexos-session-mode-switcher.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin xfconf x11-xserver-utils wmctrl; do install_if_available "$p"; done
mkdir -p /opt/nexos/session-mode "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/.config/nexos/session-mode" "$home_dir/.config/autostart" "$home_dir/NexOS/Reports"
cat > "$icon_dir/nexos-session-mode.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><rect x="27" y="33" width="74" height="48" rx="8" fill="none" stroke="#e8f7ff" stroke-width="7"/><path d="M47 99h34M64 81v18" stroke="#e8f7ff" stroke-width="7" stroke-linecap="round"/><path d="M43 57h42" stroke="#22c55e" stroke-width="7" stroke-linecap="round"/></svg>
SVG
cat > /usr/local/bin/nexos-mode-current <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
cfg="$HOME/.config/nexos/session-mode/mode"
if [[ -f "$cfg" ]]; then cat "$cfg"; else echo desktop; fi
BASH
chmod 0755 /usr/local/bin/nexos-mode-current
cat > /usr/local/bin/nexos-set-mode <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
mode="${1:-desktop}"
case "$mode" in desktop|gaming|console) ;; *) echo "Usage: nexos-set-mode desktop|gaming|console"; exit 1;; esac
mkdir -p "$HOME/.config/nexos/session-mode"
echo "$mode" > "$HOME/.config/nexos/session-mode/mode"
case "$mode" in
 desktop)
  xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior -n -t int -s 0 2>/dev/null || true
  ;;
 gaming|console)
  xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior -n -t int -s 1 2>/dev/null || true
  ;;
esac
notify-send "NexOS Session Mode" "Mode set to $mode" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-set-mode
cat > /usr/local/bin/nexos-apply-session-mode <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
mode="$(nexos-mode-current 2>/dev/null || echo desktop)"
case "$mode" in
 desktop)
  nexos-apply-branding >/dev/null 2>&1 || true
  ;;
 gaming)
  xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior -n -t int -s 1 2>/dev/null || true
  if command -v nexos-game-library >/dev/null 2>&1; then nexos-game-library >/dev/null 2>&1 & fi
  ;;
 console)
  xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior -n -t int -s 1 2>/dev/null || true
  if command -v xfce4-terminal >/dev/null 2>&1; then xfce4-terminal --fullscreen >/dev/null 2>&1 & fi
  ;;
esac
notify-send "NexOS Session Mode" "Applied $mode mode" 2>/dev/null || true
BASH
chmod 0755 /usr/local/bin/nexos-apply-session-mode
cat > /usr/local/bin/nexos-session-mode-report <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Reports/session-mode-report-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$out")"
{
echo "NexOS Session Mode Report"; echo "=========================="; date; echo
echo "Current mode: $(nexos-mode-current 2>/dev/null || echo desktop)"; echo
echo "Autostart:"; find "$HOME/.config/autostart" /etc/xdg/autostart -maxdepth 1 -name '*.desktop' -printf '%p\n' 2>/dev/null || true; echo
echo "Panel settings:"; xfconf-query -c xfce4-panel -l -v 2>/dev/null || true
} > "$out"
if command -v mousepad >/dev/null 2>&1; then mousepad "$out" >/dev/null 2>&1 & else xdg-open "$out" >/dev/null 2>&1 & fi
BASH
chmod 0755 /usr/local/bin/nexos-session-mode-report
cat > /usr/local/bin/nexos-session-mode-switcher <<'PY'
#!/usr/bin/env python3
import shutil, subprocess, tkinter as tk
from pathlib import Path
from tkinter import messagebox
CFG=Path.home()/'.config/nexos/session-mode/mode'
def current():
    try: return CFG.read_text().strip()
    except Exception: return 'desktop'
def run(c):
    e=c.split()[0]
    if shutil.which(e): subprocess.Popen(c.split(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    else: messagebox.showwarning('NexOS Session Mode',f'{e} is not installed.')
def set_mode(m):
    run('nexos-set-mode '+m); label.config(text='Current mode: '+m)
def apply(): run('nexos-apply-session-mode')
r=tk.Tk(); r.title('NexOS Session Mode Switcher'); r.geometry('820x560'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Session Mode Switcher',bg='#07111f',fg='#e8f7ff',font=('Sans',28,'bold')).pack(anchor='w',padx=24,pady=(20,4))
tk.Label(r,text='Choose how NexOS starts and behaves: normal desktop, gaming/console focused, or terminal console mode.',bg='#07111f',fg='#9bd5ff',wraplength=760,justify='left').pack(anchor='w',padx=24,pady=(0,14))
label=tk.Label(r,text='Current mode: '+current(),bg='#07111f',fg='#86efac',font=('Sans',13,'bold')); label.pack(anchor='w',padx=24,pady=(0,12))
f=tk.Frame(r,bg='#07111f',padx=24); f.pack(fill='both',expand=True)
for title,mode,desc in [('Desktop Mode','desktop','Normal NexOS desktop with dock/panel visible.'),('Gaming Mode','gaming','Autohide panel and open game library on startup.'),('Console Mode','console','Autohide panel and open fullscreen terminal.')]:
    card=tk.Frame(f,bg='#0d172b',padx=16,pady=14,highlightbackground='#294866',highlightthickness=1); card.pack(fill='x',pady=7)
    tk.Label(card,text=title,bg='#0d172b',fg='#e8f7ff',font=('Sans',15,'bold')).pack(anchor='w')
    tk.Label(card,text=desc,bg='#0d172b',fg='#9bd5ff',wraplength=700,justify='left').pack(anchor='w',pady=(3,8))
    tk.Button(card,text='Set '+title,command=lambda m=mode:set_mode(m),bg='#1f2937',fg='#e8f7ff',relief='flat',padx=14,pady=8).pack(anchor='e')
bar=tk.Frame(r,bg='#07111f'); bar.pack(fill='x',padx=24,pady=16)
for n,c in [('Apply Now',apply),('Report',lambda:run('nexos-session-mode-report')),('Settings',lambda:run('nexos-settings')),('Gaming Center',lambda:run('nexos-gaming-center'))]: tk.Button(bar,text=n,command=c,bg='#0ea5e9' if n=='Apply Now' else '#1f2937',fg='white' if n=='Apply Now' else '#e8f7ff',relief='flat',padx=14,pady=10).pack(side='left',padx=4)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-session-mode-switcher
cat > "$home_dir/.config/autostart/nexos-apply-session-mode.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Apply Session Mode
Exec=nexos-apply-session-mode
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP
for spec in "nexos-session-mode-switcher|NexOS Session Mode Switcher|Settings;System;" "nexos-session-mode-report|NexOS Session Mode Report|System;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-session-mode.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-session-mode-switcher' not in s: p.write_text(s.replace('\n]', '\n    ("Modes", ["nexos-session-mode-switcher"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('session mode','nexos-session-mode-switcher','NexOS Session Mode Switcher'),('desktop mode','nexos-set-mode desktop','NexOS Desktop Mode'),('gaming mode','nexos-set-mode gaming','NexOS Gaming Mode'),('console mode','nexos-set-mode console','NexOS Console Mode'),('apply session mode','nexos-apply-session-mode','NexOS Apply Session Mode')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Session Mode Switcher:
- Adds Desktop/Gaming/Console startup modes, apply helper, mode report, autostart applier, dock/menu entries, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/340-nexos-session-mode-switcher.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/340-nexos-session-mode-switcher.hook.chroot"
success "Injected NexOS Session Mode Switcher for $NEXOS_EDITION."
