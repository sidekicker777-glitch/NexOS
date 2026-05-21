#!/usr/bin/env bash
# NexOS Final Build Smoke Test Pack: one-click runtime/source smoke tests for apps, launchers, assistant catalog, package safety and ISO readiness.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/91-nexos-final-smoke-test-pack.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
bash
coreutils
findutils
grep
sed
procps
jq
desktop-file-utils
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/500-nexos-final-smoke-test-pack.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin bash coreutils findutils grep sed procps jq desktop-file-utils; do install_if_available "$p"; done
mkdir -p /opt/nexos/final-smoke-test "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/NexOS/Reports"
cat > "$icon_dir/nexos-final-smoke-test.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><path d="M34 37h60v54H34z" fill="none" stroke="#e8f7ff" stroke-width="7" stroke-linejoin="round"/><path d="M45 57l12 12 26-27" fill="none" stroke="#22c55e" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/><path d="M45 88h38" stroke="#38bdf8" stroke-width="6" stroke-linecap="round"/></svg>
SVG
cat > /usr/local/bin/nexos-final-smoke-test <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
report="$HOME/NexOS/Reports/final-smoke-test-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$report")"
pass=0; warn=0; fail=0
check(){ local name="$1"; shift; if "$@" >/tmp/nexos-smoke-check.out 2>&1; then echo "PASS: $name"; pass=$((pass+1)); else echo "FAIL: $name"; sed 's/^/  /' /tmp/nexos-smoke-check.out; fail=$((fail+1)); fi; }
soft(){ local name="$1"; shift; if "$@" >/tmp/nexos-smoke-check.out 2>&1; then echo "PASS: $name"; pass=$((pass+1)); else echo "WARN: $name"; sed 's/^/  /' /tmp/nexos-smoke-check.out; warn=$((warn+1)); fi; }
{
echo "NexOS Final Build Smoke Test Pack"
echo "================================="
date
echo
check "Control Panel command exists" command -v nexos-control-panel
check "Action Center command exists" command -v nexos-action-center
check "Settings command exists" command -v nexos-settings
check "Search Center command exists" command -v nexos-search-center
check "Power Center command exists" command -v nexos-power-center
check "Network Center command exists" command -v nexos-network-center
check "Security Center command exists" command -v nexos-security-center
check "Task Manager command exists" command -v nexos-task-manager
check "Backup Center command exists" command -v nexos-backup-restore-center
check "Personalization command exists" command -v nexos-personalization-center
check "Desktop UX finalizer exists" command -v nexos-desktop-ux-finalize
check "App icon fix pass exists" command -v nexos-app-icon-fix-pass
soft "Assistant catalog exists" test -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json
soft "AI assistant toggle exists" command -v nexos-assistant-toggle
soft "NexOS app map exists" test -f /usr/share/nexos/app-map.txt
soft "NexOS release file exists" test -f /usr/share/nexos/nexos-release
soft "Desktop entries exist" bash -lc 'ls /usr/share/applications/nexos-*.desktop >/dev/null 2>&1'
soft "NexOS icons exist" bash -lc 'ls /usr/share/icons/hicolor/scalable/apps/nexos-*.svg >/dev/null 2>&1'
soft "Desktop validation no missing critical Exec markers" bash -lc 'for f in /usr/share/applications/nexos-*.desktop; do grep -q ^Exec= "$f" || exit 1; done'
soft "Desktop validation no missing critical Icon markers" bash -lc 'for f in /usr/share/applications/nexos-*.desktop; do grep -q ^Icon= "$f" || exit 1; done'
soft "Package safety script visible in source tree" test -f scripts/19-fix-nexos-package-lists.sh
soft "ISO Doctor visible in source tree" test -f scripts/53-inject-nexos-iso-doctor.sh
soft "Build validation script visible in source tree" test -f scripts/55-inject-nexos-build-validation-report.sh
echo
echo "Summary: PASS=$pass WARN=$warn FAIL=$fail"
echo
echo "Top NexOS commands:"
find /usr/local/bin -maxdepth 1 -type f -executable -name 'nexos-*' -printf '  %f\n' 2>/dev/null | sort | head -250 || true
echo
echo "NexOS desktop apps:"
find /usr/share/applications -maxdepth 1 -type f -name 'nexos-*.desktop' -printf '  %f\n' 2>/dev/null | sort | head -250 || true
echo
echo "Recent reports:"
find "$HOME/NexOS/Reports" -maxdepth 1 -type f -printf '  %TY-%Tm-%Td %TH:%TM %p\n' 2>/dev/null | sort -r | head -40 || true
} > "$report"
rm -f /tmp/nexos-smoke-check.out
notify-send "NexOS Smoke Test" "Final smoke test complete" 2>/dev/null || true
echo "$report"
if [[ "$fail" -gt 0 ]]; then exit 2; fi
BASH
chmod 0755 /usr/local/bin/nexos-final-smoke-test
cat > /usr/local/bin/nexos-final-smoke-test-center <<'PY'
#!/usr/bin/env python3
import subprocess, tkinter as tk
from pathlib import Path
last=None
def run_test():
    global last
    p=subprocess.run(['nexos-final-smoke-test'],text=True,capture_output=True)
    last=(p.stdout.strip().splitlines() or [''])[0]
    txt.delete('1.0','end')
    if last and Path(last).exists(): txt.insert('1.0',Path(last).read_text(errors='ignore'))
    else: txt.insert('1.0',p.stdout+p.stderr)
def open_reports(): subprocess.Popen(['xdg-open',str(Path.home()/'NexOS/Reports')])
r=tk.Tk(); r.title('NexOS Final Smoke Test Pack'); r.geometry('1080x720'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Final Smoke Test Pack',bg='#07111f',fg='#e8f7ff',font=('Sans',31,'bold')).pack(anchor='w',padx=24,pady=(20,4))
tk.Label(r,text='One-click smoke tests for desktop apps, launchers, icons, assistant catalog, package-safety visibility, and ISO readiness.',bg='#07111f',fg='#9bd5ff',wraplength=940,justify='left').pack(anchor='w',padx=24,pady=(0,12))
bar=tk.Frame(r,bg='#07111f'); bar.pack(fill='x',padx=24,pady=8)
tk.Button(bar,text='Run Smoke Test',command=run_test,bg='#0ea5e9',fg='white',relief='flat',padx=14,pady=10).pack(side='left',padx=4)
tk.Button(bar,text='Open Reports',command=open_reports,bg='#1f2937',fg='#e8f7ff',relief='flat',padx=14,pady=10).pack(side='left',padx=4)
txt=tk.Text(r,bg='#0d172b',fg='#e8f7ff',insertbackground='#e8f7ff',relief='flat',font=('DejaVu Sans Mono',9)); txt.pack(fill='both',expand=True,padx=24,pady=12)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-final-smoke-test-center
for spec in "nexos-final-smoke-test-center|NexOS Final Smoke Test Pack|System;Development;" "nexos-final-smoke-test|NexOS Final Smoke Test CLI|System;Development;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-final-smoke-test.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-control-panel ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-control-panel'); s=p.read_text()
needle='["Build Validation", "nexos-build-validation-report-gui", "Included feature and app report"],'
if 'nexos-final-smoke-test-center' not in s:
    s=s.replace(needle, needle+'\n    ["Final Smoke Test", "nexos-final-smoke-test-center", "One-click ISO readiness checks"],')
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-control-panel; fi
if [[ -f /usr/local/bin/nexos-action-center ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-action-center'); s=p.read_text()
if "('Smoke Test','nexos-final-smoke-test-center')" not in s:
    s=s.replace("('Task Manager','nexos-task-manager')", "('Task Manager','nexos-task-manager'),('Smoke Test','nexos-final-smoke-test-center')")
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-action-center; fi
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-final-smoke-test-center' not in s: p.write_text(s.replace('\n]', '\n    ("Smoke", ["nexos-final-smoke-test-center"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('final smoke test','nexos-final-smoke-test-center','NexOS Final Smoke Test Pack'),('run smoke test','nexos-final-smoke-test','Run NexOS Smoke Test'),('iso readiness','nexos-final-smoke-test-center','NexOS Final Smoke Test Pack')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Final Build Smoke Test Pack:
- Adds one-click smoke tests for core NexOS apps, launcher icons, AI assistant catalog, package safety/source visibility, ISO readiness, reports, Control Panel integration, Action Center integration, dock/menu entries, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/500-nexos-final-smoke-test-pack.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/500-nexos-final-smoke-test-pack.hook.chroot"
success "Injected NexOS Final Build Smoke Test Pack for $NEXOS_EDITION."
