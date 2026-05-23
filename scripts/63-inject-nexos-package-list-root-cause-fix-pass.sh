#!/usr/bin/env bash
# NexOS Package-List Root Cause Fix Pass: sanitizes hard package lists and reports exact package blockers before lb build.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/96-nexos-package-list-root-cause-fix-pass.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
bash
coreutils
findutils
grep
sed
jq
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/545-nexos-package-list-root-cause-fix-pass.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin bash coreutils findutils grep sed jq; do install_if_available "$p"; done
mkdir -p /opt/nexos/package-list-fix "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/NexOS/Reports"
cat > "$icon_dir/nexos-package-list-fix.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><path d="M35 28h58v72H35z" fill="none" stroke="#e8f7ff" stroke-width="7" stroke-linejoin="round"/><path d="M48 49h31M48 66h31M48 83h20" stroke="#38bdf8" stroke-width="6" stroke-linecap="round"/><path d="M78 88l8 8 21-28" fill="none" stroke="#22c55e" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/></svg>
SVG
cat > /usr/local/bin/nexos-package-list-root-cause-fix <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
root="${1:-$(pwd)}"
out="$HOME/NexOS/Reports/package-list-root-cause-fix-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$out")"
{
echo "NexOS Package-List Root Cause Fix Pass"
echo "======================================="
date
echo
echo "Scan root: $root"
echo
for dir in "$root/live-build/config/package-lists" "$root/config/package-lists"; do
  echo "Package list directory: $dir"
  if [[ ! -d "$dir" ]]; then echo "  missing"; echo; continue; fi
  total=0; comments=0; blanks=0
  while IFS= read -r f; do
    c="$(grep -vE '^[[:space:]]*(#|$)' "$f" | wc -l | tr -d ' ')"
    total=$((total+c))
    comments=$((comments+$(grep -cE '^[[:space:]]*#' "$f" || true)))
    blanks=$((blanks+$(grep -cE '^[[:space:]]*$' "$f" || true)))
    echo "  $(basename "$f"): $c hard package lines"
  done < <(find "$dir" -maxdepth 1 -type f -name '*.list.chroot' | sort)
  echo "  total hard package lines: $total"
  echo "  comment lines: $comments"
  echo "  blank lines: $blanks"
  echo
done
echo "Moved optional/unavailable package logs:"
for f in "$root/live-build/config/nexos-removed-optional-packages.txt" "$root/config/nexos-removed-optional-packages.txt"; do
  echo "## $f"
  [[ -f "$f" ]] && sed 's/^/  - /' "$f" || echo "  missing"
done
echo
echo "Live-build package error markers:"
grep -RniE 'Unable to locate package|Package .* has no installation candidate|E: The package|not going to be installed|held broken packages|Conflicts:|Depends:' "$root/build/logs" 2>/dev/null | head -120 || echo "  none found"
} > "$out"
notify-send "NexOS Package List Fix" "Package-list report generated" 2>/dev/null || true
echo "$out"
BASH
chmod 0755 /usr/local/bin/nexos-package-list-root-cause-fix
cat > /usr/local/bin/nexos-package-list-root-cause-fix-gui <<'PY'
#!/usr/bin/env python3
import subprocess, tkinter as tk
from pathlib import Path
last=None
def run_fix():
    global last
    p=subprocess.run(['nexos-package-list-root-cause-fix'],text=True,capture_output=True)
    last=(p.stdout.strip().splitlines() or [''])[0]
    txt.delete('1.0','end')
    if last and Path(last).exists(): txt.insert('1.0',Path(last).read_text(errors='ignore'))
    else: txt.insert('1.0',p.stdout+p.stderr)
def open_reports(): subprocess.Popen(['xdg-open',str(Path.home()/'NexOS/Reports')])
r=tk.Tk(); r.title('NexOS Package-List Root Cause Fix Pass'); r.geometry('1080x720'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Package-List Root Cause Fix Pass',bg='#07111f',fg='#e8f7ff',font=('Sans',30,'bold')).pack(anchor='w',padx=24,pady=(20,4))
tk.Label(r,text='Reports hard package lists, moved optional packages, and package error markers that commonly cause live-build exit code 2.',bg='#07111f',fg='#9bd5ff',wraplength=980,justify='left').pack(anchor='w',padx=24,pady=(0,12))
bar=tk.Frame(r,bg='#07111f'); bar.pack(fill='x',padx=24,pady=8)
tk.Button(bar,text='Run Package Scan',command=run_fix,bg='#0ea5e9',fg='white',relief='flat',padx=14,pady=10).pack(side='left',padx=4)
tk.Button(bar,text='Open Reports',command=open_reports,bg='#1f2937',fg='#e8f7ff',relief='flat',padx=14,pady=10).pack(side='left',padx=4)
txt=tk.Text(r,bg='#0d172b',fg='#e8f7ff',insertbackground='#e8f7ff',relief='flat',font=('DejaVu Sans Mono',9)); txt.pack(fill='both',expand=True,padx=24,pady=12)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-package-list-root-cause-fix-gui
for spec in "nexos-package-list-root-cause-fix-gui|NexOS Package-List Root Cause Fix Pass|System;Development;" "nexos-package-list-root-cause-fix|NexOS Package-List Root Cause Fix CLI|System;Development;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-package-list-fix.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-control-panel ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-control-panel'); s=p.read_text()
needle='["Live-Build Fix", "nexos-live-build-failure-auto-fix-gui", "Diagnose ISO build failures"],'
if 'nexos-package-list-root-cause-fix-gui' not in s:
    s=s.replace(needle, needle+'\n    ["Package Root Fix", "nexos-package-list-root-cause-fix-gui", "Package-list build blocker scan"],')
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-control-panel; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json')
d=json.loads(p.read_text())
for k,c,l in [('package root fix','nexos-package-list-root-cause-fix-gui','NexOS Package-List Root Cause Fix'),('package list fix','nexos-package-list-root-cause-fix-gui','NexOS Package-List Root Cause Fix'),('scan packages','nexos-package-list-root-cause-fix','Scan Package Lists')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Package-List Root Cause Fix Pass:
- Adds package-list root-cause report, hard package count summary, optional/unavailable package logs, live-build package error marker extraction, Control Panel integration, app menu entries, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/545-nexos-package-list-root-cause-fix-pass.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/545-nexos-package-list-root-cause-fix-pass.hook.chroot"
success "Injected NexOS Package-List Root Cause Fix Pass for $NEXOS_EDITION."
