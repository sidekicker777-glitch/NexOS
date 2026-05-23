#!/usr/bin/env bash
# NexOS Live-Build Failure Auto-Fix Pass: runtime/source helper that diagnoses common live-build exit-code-2 failures.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/95-nexos-live-build-failure-auto-fix-pass.list.chroot" <<'PKGS'
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
cat > "$LB_CONFIG_DIR/hooks/normal/540-nexos-live-build-failure-auto-fix-pass.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin bash coreutils findutils grep sed jq; do install_if_available "$p"; done
mkdir -p /opt/nexos/live-build-fix "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/NexOS/Reports"
cat > "$icon_dir/nexos-live-build-fix.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><path d="M34 36h60v20H34zM34 72h60v20H34z" fill="none" stroke="#e8f7ff" stroke-width="7" stroke-linejoin="round"/><path d="M47 46h24M47 82h24" stroke="#38bdf8" stroke-width="6" stroke-linecap="round"/><path d="M82 94l20 20M102 94l-20 20" stroke="#22c55e" stroke-width="7" stroke-linecap="round"/></svg>
SVG
cat > /usr/local/bin/nexos-live-build-failure-auto-fix <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Reports/live-build-failure-auto-fix-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$out")"
root="${1:-$(pwd)}"
{
echo "NexOS Live-Build Failure Auto-Fix Pass"
echo "======================================="
date
echo
echo "Scan root: $root"
echo
if [[ ! -d "$root" ]]; then echo "WARN: scan root does not exist."; fi
log_files=()
while IFS= read -r f; do log_files+=("$f"); done < <(find "$root" -path '*/build/logs/*' -type f 2>/dev/null | sort || true)
echo "Logs found: ${#log_files[@]}"
echo
if ((${#log_files[@]})); then
  echo "First critical markers:"
  grep -RniE 'E: |ERROR:|Failed|failed|unable to locate|not found|No such file|syntax error|dpkg returned|lb build|chroot|package.*has no installation candidate' "${log_files[@]}" 2>/dev/null | grep -vi 'Optional runner package not available' | head -80 || echo "- none found"
else
  echo "No build/logs files found. Download/extract the GitHub artifact or run this from repo root after a failed build."
fi
echo
echo "Common auto-fix recommendations:"
echo "- If package names are shown as unavailable, move them from hard package lists to optional hooks."
echo "- If hooks are missing, verify scripts/19-fix-nexos-package-lists.sh wires every late injector."
echo "- If report paths are empty, scan live-build/config instead of config."
echo "- If lb build fails after package safety, inspect github-actions-main-iso.log tail, not only the summary."
echo "- If the run shown is from a pull_request older than latest main, rerun the workflow on the newest commit."
echo
echo "Generated live-build config visibility:"
for d in "$root/live-build/config/package-lists" "$root/live-build/config/hooks/normal" "$root/config/package-lists" "$root/config/hooks/normal"; do
  echo; echo "## $d"; find "$d" -maxdepth 1 -type f -printf '- %f\n' 2>/dev/null | head -120 || echo "- not found"
done
} > "$out"
notify-send "NexOS Live-Build Fix" "Failure auto-fix report generated" 2>/dev/null || true
echo "$out"
BASH
chmod 0755 /usr/local/bin/nexos-live-build-failure-auto-fix
cat > /usr/local/bin/nexos-live-build-failure-auto-fix-gui <<'PY'
#!/usr/bin/env python3
import subprocess, tkinter as tk
from pathlib import Path
last=None
def run_fix():
    global last
    p=subprocess.run(['nexos-live-build-failure-auto-fix'],text=True,capture_output=True)
    last=(p.stdout.strip().splitlines() or [''])[0]
    txt.delete('1.0','end')
    if last and Path(last).exists(): txt.insert('1.0',Path(last).read_text(errors='ignore'))
    else: txt.insert('1.0',p.stdout+p.stderr)
def open_reports(): subprocess.Popen(['xdg-open',str(Path.home()/'NexOS/Reports')])
r=tk.Tk(); r.title('NexOS Live-Build Failure Auto-Fix Pass'); r.geometry('1080x720'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Live-Build Failure Auto-Fix Pass',bg='#07111f',fg='#e8f7ff',font=('Sans',30,'bold')).pack(anchor='w',padx=24,pady=(20,4))
tk.Label(r,text='Scans build logs and live-build config for common exit-code-2 causes: bad packages, missing hooks, bad paths, and stale workflow runs.',bg='#07111f',fg='#9bd5ff',wraplength=980,justify='left').pack(anchor='w',padx=24,pady=(0,12))
bar=tk.Frame(r,bg='#07111f'); bar.pack(fill='x',padx=24,pady=8)
tk.Button(bar,text='Run Auto-Fix Scan',command=run_fix,bg='#0ea5e9',fg='white',relief='flat',padx=14,pady=10).pack(side='left',padx=4)
tk.Button(bar,text='Open Reports',command=open_reports,bg='#1f2937',fg='#e8f7ff',relief='flat',padx=14,pady=10).pack(side='left',padx=4)
txt=tk.Text(r,bg='#0d172b',fg='#e8f7ff',insertbackground='#e8f7ff',relief='flat',font=('DejaVu Sans Mono',9)); txt.pack(fill='both',expand=True,padx=24,pady=12)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-live-build-failure-auto-fix-gui
for spec in "nexos-live-build-failure-auto-fix-gui|NexOS Live-Build Failure Auto-Fix Pass|System;Development;" "nexos-live-build-failure-auto-fix|NexOS Live-Build Failure Auto-Fix CLI|System;Development;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-live-build-fix.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-control-panel ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-control-panel'); s=p.read_text()
needle='["Release Notes", "nexos-release-notes-center", "Generate ISO change notes"],'
if 'nexos-live-build-failure-auto-fix-gui' not in s:
    s=s.replace(needle, needle+'\n    ["Live-Build Fix", "nexos-live-build-failure-auto-fix-gui", "Diagnose ISO build failures"],')
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-control-panel; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json')
d=json.loads(p.read_text())
for k,c,l in [('live build fix','nexos-live-build-failure-auto-fix-gui','NexOS Live-Build Failure Auto-Fix'),('fix iso build','nexos-live-build-failure-auto-fix-gui','NexOS Live-Build Failure Auto-Fix'),('scan build logs','nexos-live-build-failure-auto-fix','Scan Build Logs')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Live-Build Failure Auto-Fix Pass:
- Adds live-build failure scanner, exit-code-2 helper report, critical log marker extraction, generated package/hook visibility checks, Control Panel integration, app menu entries, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/540-nexos-live-build-failure-auto-fix-pass.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/540-nexos-live-build-failure-auto-fix-pass.hook.chroot"
success "Injected NexOS Live-Build Failure Auto-Fix Pass for $NEXOS_EDITION."
