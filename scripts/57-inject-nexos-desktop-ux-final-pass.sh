#!/usr/bin/env bash
# NexOS Desktop UX Final Pass: first-boot polish pipeline, readiness report, dock/panel/icon/app validation refresh.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/90-nexos-desktop-ux-final-pass.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
xfconf
xfce4-panel
xfce4-settings
hicolor-icon-theme
desktop-file-utils
glib2.0-bin
procps
findutils
coreutils
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/490-nexos-desktop-ux-final-pass.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin xfconf xfce4-panel xfce4-settings hicolor-icon-theme desktop-file-utils glib2.0-bin procps findutils coreutils; do install_if_available "$p"; done
mkdir -p /opt/nexos/desktop-ux-final "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/.config/nexos/desktop-ux" "$home_dir/.config/autostart" "$home_dir/NexOS/Reports"
cat > "$icon_dir/nexos-desktop-ux-final.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><rect x="25" y="29" width="78" height="55" rx="9" fill="none" stroke="#e8f7ff" stroke-width="7"/><path d="M34 95h60" stroke="#22c55e" stroke-width="8" stroke-linecap="round"/><path d="M43 47h42M43 63h22" stroke="#38bdf8" stroke-width="6" stroke-linecap="round"/><path d="M75 69l8 8 17-21" fill="none" stroke="#22c55e" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/></svg>
SVG
cat > /usr/local/bin/nexos-desktop-readiness-report <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Reports/desktop-readiness-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$out")"
{
echo "NexOS Desktop UX Final Readiness Report"; echo "========================================"; date; echo
echo "Current session:"; echo "  DESKTOP_SESSION=${DESKTOP_SESSION:-}"; echo "  XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-}"; echo
echo "NexOS commands:"; find /usr/local/bin -maxdepth 1 -type f -executable -name 'nexos-*' -printf '  %f\n' 2>/dev/null | sort | head -300; echo
echo "Desktop shortcuts:"; find "$HOME/Desktop" -maxdepth 2 -type f -name '*.desktop' -printf '  %m %p\n' 2>/dev/null | sort || true; echo
echo "NexOS launchers missing Exec/Icon markers:"; for f in /usr/share/applications/nexos-*.desktop "$HOME/Desktop"/nexos-*.desktop; do [[ -f "$f" ]] || continue; grep -q '^Exec=' "$f" || echo "  missing Exec: $f"; grep -q '^Icon=' "$f" || echo "  missing Icon: $f"; done; echo
echo "Panel settings:"; xfconf-query -c xfce4-panel -l -v 2>/dev/null | head -260 || true; echo
echo "Theme settings:"; xfconf-query -c xsettings -l -v 2>/dev/null | grep -E 'Theme|Icon|Font' || true; echo
echo "Wallpaper settings:"; xfconf-query -c xfce4-desktop -l -v 2>/dev/null | grep -E 'last-image|image-style' || true; echo
echo "Autostart NexOS entries:"; find "$HOME/.config/autostart" /etc/xdg/autostart -maxdepth 1 -type f -name 'nexos*.desktop' -printf '  %p\n' 2>/dev/null | sort || true; echo
echo "Recent generated reports:"; find "$HOME/NexOS/Reports" -maxdepth 1 -type f -printf '  %TY-%Tm-%Td %TH:%TM %p\n' 2>/dev/null | sort -r | head -50 || true
} > "$out"
if command -v mousepad >/dev/null 2>&1; then mousepad "$out" >/dev/null 2>&1 & else xdg-open "$out" >/dev/null 2>&1 & fi
echo "$out"
BASH
chmod 0755 /usr/local/bin/nexos-desktop-readiness-report
cat > /usr/local/bin/nexos-desktop-ux-finalize <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/.config/nexos/desktop-ux" "$HOME/NexOS/Reports"
log="$HOME/NexOS/Reports/desktop-ux-finalize-$(date +%Y%m%d-%H%M%S).log"
{
echo "NexOS Desktop UX Finalize"; echo "========================="; date; echo
run_step(){ echo; echo "== $1 =="; shift; "$@" || true; }
run_step "Apply NexOS branding" nexos-apply-branding
run_step "Apply NexOS dark theme" nexos-theme-apply dark
run_step "Apply NexOS panel layout" nexos-panel-layout-apply nexos
run_step "Create desktop shortcuts" nexos-create-desktop-shortcuts
run_step "Trust launchers" nexos-trust-launchers
run_step "Clean duplicate desktop icons" nexos-clean-desktop-icons
run_step "Fix app/icon launchers" nexos-app-icon-fix-pass
run_step "Refresh desktop database" update-desktop-database /usr/share/applications
run_step "Refresh icon cache" gtk-update-icon-cache -f /usr/share/icons/hicolor
run_step "Apply session mode" nexos-apply-session-mode
run_step "Restart XFCE panel" xfce4-panel -r
run_step "Generate desktop readiness report" nexos-desktop-readiness-report
echo "done"
} > "$log" 2>&1
notify-send "NexOS Desktop" "Desktop UX final pass complete" 2>/dev/null || true
echo "$log"
BASH
chmod 0755 /usr/local/bin/nexos-desktop-ux-finalize
cat > /usr/local/bin/nexos-desktop-ux-final-center <<'PY'
#!/usr/bin/env python3
import subprocess, tkinter as tk
from pathlib import Path
from tkinter import messagebox
last=None
def run_cmd(cmd):
    global last
    p=subprocess.run(cmd,text=True,capture_output=True)
    last=(p.stdout.strip().splitlines() or [''])[0]
    txt.delete('1.0','end')
    if last and Path(last).exists(): txt.insert('1.0',Path(last).read_text(errors='ignore'))
    else: txt.insert('1.0',p.stdout+p.stderr)
def finalize():
    if messagebox.askyesno('NexOS Desktop UX Final Pass','Run full desktop finalize pass now?'):
        run_cmd(['nexos-desktop-ux-finalize'])
def report(): run_cmd(['nexos-desktop-readiness-report'])
def open_reports(): subprocess.Popen(['xdg-open',str(Path.home()/'NexOS/Reports')])
r=tk.Tk(); r.title('NexOS Desktop UX Final Pass'); r.geometry('1040x720'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Desktop UX Final Pass',bg='#07111f',fg='#e8f7ff',font=('Sans',31,'bold')).pack(anchor='w',padx=24,pady=(20,4))
tk.Label(r,text='Final first-boot polish: branding, theme, panel, shortcuts, icon validation, launcher trust, dock/panel refresh and readiness report.',bg='#07111f',fg='#9bd5ff',wraplength=940,justify='left').pack(anchor='w',padx=24,pady=(0,12))
bar=tk.Frame(r,bg='#07111f'); bar.pack(fill='x',padx=24,pady=8)
for n,c,bg in [('Run Final Pass',finalize,'#0ea5e9'),('Readiness Report',report,'#1f2937'),('Open Reports',open_reports,'#1f2937')]: tk.Button(bar,text=n,command=c,bg=bg,fg='white' if bg=='#0ea5e9' else '#e8f7ff',relief='flat',padx=14,pady=10).pack(side='left',padx=4)
txt=tk.Text(r,bg='#0d172b',fg='#e8f7ff',insertbackground='#e8f7ff',relief='flat',font=('DejaVu Sans Mono',9)); txt.pack(fill='both',expand=True,padx=24,pady=12)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-desktop-ux-final-center
for spec in "nexos-desktop-ux-final-center|NexOS Desktop UX Final Pass|Settings;DesktopSettings;" "nexos-desktop-readiness-report|NexOS Desktop Readiness Report|System;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-desktop-ux-final.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
cat > "$home_dir/.config/autostart/nexos-desktop-ux-finalize.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Desktop UX Finalize
Exec=sh -c 'test -f "$HOME/.config/nexos/desktop-ux/finalized" || (nexos-desktop-ux-finalize && mkdir -p "$HOME/.config/nexos/desktop-ux" && touch "$HOME/.config/nexos/desktop-ux/finalized")'
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP
if [[ -f /usr/local/bin/nexos-control-panel ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-control-panel'); s=p.read_text()
needle='["App Icons", "nexos-app-icon-validation-center", "Launcher and icon validation"]'
if 'nexos-desktop-ux-final-center' not in s:
    s=s.replace(needle, needle + ',\n    ["Desktop UX Final", "nexos-desktop-ux-final-center", "Final desktop polish and readiness"]')
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-control-panel; fi
if [[ -f /usr/local/bin/nexos-action-center ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-action-center'); s=p.read_text()
if "('UX Final','nexos-desktop-ux-final-center')" not in s:
    s=s.replace("('App Icons','nexos-app-icon-validation-center')", "('App Icons','nexos-app-icon-validation-center'),('UX Final','nexos-desktop-ux-final-center')")
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-action-center; fi
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-desktop-ux-final-center' not in s: p.write_text(s.replace('\n]', '\n    ("UX Final", ["nexos-desktop-ux-final-center"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('desktop ux final','nexos-desktop-ux-final-center','NexOS Desktop UX Final Pass'),('final desktop polish','nexos-desktop-ux-finalize','Run Desktop UX Finalize'),('desktop readiness report','nexos-desktop-readiness-report','NexOS Desktop Readiness Report')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Desktop UX Final Pass:
- Adds full first-boot desktop polish pipeline, branding/theme/layout/app-icon validation/shortcut creation/trust fixes, panel refresh, readiness report, autostart finalizer, Control Panel integration, Action Center integration, dock/menu entries, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/490-nexos-desktop-ux-final-pass.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/490-nexos-desktop-ux-final-pass.hook.chroot"
success "Injected NexOS Desktop UX Final Pass for $NEXOS_EDITION."
