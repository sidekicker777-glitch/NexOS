#!/usr/bin/env bash
# NexOS Release Readiness Center: combines ISO Doctor, Build Fix, Build Validation, Final Smoke, Desktop UX, App/Icon checks and workflow reports.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/92-nexos-release-readiness-center.list.chroot" <<'PKGS'
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
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/510-nexos-release-readiness-center.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin bash coreutils findutils grep sed procps jq; do install_if_available "$p"; done
mkdir -p /opt/nexos/release-readiness "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/NexOS/Reports"
cat > "$icon_dir/nexos-release-readiness.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><path d="M33 34h62v70H33z" fill="none" stroke="#e8f7ff" stroke-width="7" stroke-linejoin="round"/><path d="M46 55h36M46 72h36M46 89h21" stroke="#38bdf8" stroke-width="6" stroke-linecap="round"/><path d="M72 91l9 9 22-30" fill="none" stroke="#22c55e" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/></svg>
SVG
cat > /usr/local/bin/nexos-release-readiness-report <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Reports/release-readiness-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$out")"
pass=0; warn=0; fail=0
check(){ local name="$1"; shift; if "$@" >/tmp/nexos-release-check.out 2>&1; then echo "PASS: $name"; pass=$((pass+1)); else echo "FAIL: $name"; sed 's/^/  /' /tmp/nexos-release-check.out; fail=$((fail+1)); fi; }
soft(){ local name="$1"; shift; if "$@" >/tmp/nexos-release-check.out 2>&1; then echo "PASS: $name"; pass=$((pass+1)); else echo "WARN: $name"; sed 's/^/  /' /tmp/nexos-release-check.out; warn=$((warn+1)); fi; }
{
echo "NexOS Release Readiness Report"
echo "==============================="
date
echo
echo "Core readiness checks"
echo "---------------------"
check "Control Panel exists" command -v nexos-control-panel
check "Final Smoke Test exists" command -v nexos-final-smoke-test
check "Desktop UX Finalizer exists" command -v nexos-desktop-ux-finalize
check "App/Icon Fix Pass exists" command -v nexos-app-icon-fix-pass
soft "ISO Doctor exists" command -v nexos-iso-doctor
soft "Build Fix Pass exists" command -v nexos-build-fix-pass
soft "Build Validation Report exists" command -v nexos-build-validation-report
soft "Desktop readiness report exists" command -v nexos-desktop-readiness-report
soft "GitHub workflow source exists" test -f .github/workflows/build-nexos-iso.yml
soft "Package safety source exists" test -f scripts/19-fix-nexos-package-lists.sh
soft "Release readiness source exists" test -f scripts/59-inject-nexos-release-readiness-center.sh
echo
echo "Recent reports"
echo "--------------"
find "$HOME/NexOS/Reports" -maxdepth 1 -type f -printf '  %TY-%Tm-%Td %TH:%TM %p\n' 2>/dev/null | sort -r | head -80 || true
echo
echo "Latest report previews"
echo "----------------------"
for pattern in final-smoke-test desktop-readiness app-icon-validation build-validation iso-doctor release-readiness; do
  latest="$(find "$HOME/NexOS/Reports" -maxdepth 1 -type f -name "*$pattern*" -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR==1{$1=""; sub(/^ /,""); print}' || true)"
  [[ -n "$latest" && -f "$latest" ]] || continue
  echo; echo "===== $latest ====="; sed -n '1,80p' "$latest" || true
done
echo
echo "Expected release tools"
echo "----------------------"
for c in nexos-iso-doctor-gui nexos-build-fix-pass-gui nexos-build-validation-report-gui nexos-final-smoke-test-center nexos-desktop-ux-final-center nexos-app-icon-validation-center nexos-control-panel; do
  if command -v "$c" >/dev/null 2>&1; then echo "  OK $c"; else echo "  MISSING $c"; fi
done
echo
echo "Source late injector coverage"
echo "-----------------------------"
if [[ -d scripts ]]; then find scripts -maxdepth 1 -type f -name '[5][0-9]-inject-nexos-*.sh' -printf '  %f\n' | sort -V || true; else echo "  Source tree not present in runtime ISO."; fi
echo
echo "Summary: PASS=$pass WARN=$warn FAIL=$fail"
} > "$out"
rm -f /tmp/nexos-release-check.out
notify-send "NexOS Release Readiness" "Release readiness report generated" 2>/dev/null || true
echo "$out"
BASH
chmod 0755 /usr/local/bin/nexos-release-readiness-report
cat > /usr/local/bin/nexos-release-readiness-run-all <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
log="$HOME/NexOS/Reports/release-readiness-run-all-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$(dirname "$log")"
{
echo "NexOS Release Readiness Run All"
echo "==============================="
date
run_step(){ echo; echo "== $1 =="; shift; "$@" || true; }
run_step "App/Icon Fix Pass" nexos-app-icon-fix-pass
run_step "Desktop UX Finalize" nexos-desktop-ux-finalize
run_step "Final Smoke Test" nexos-final-smoke-test
run_step "Desktop Readiness Report" nexos-desktop-readiness-report
run_step "Build Validation Report" nexos-build-validation-report
run_step "ISO Doctor" nexos-iso-doctor
run_step "Release Readiness Report" nexos-release-readiness-report
echo; echo "done"
} > "$log" 2>&1
notify-send "NexOS Release Readiness" "Run-all completed" 2>/dev/null || true
echo "$log"
BASH
chmod 0755 /usr/local/bin/nexos-release-readiness-run-all
cat > /usr/local/bin/nexos-release-readiness-center <<'PY'
#!/usr/bin/env python3
import shutil, subprocess, tkinter as tk
from pathlib import Path
from tkinter import ttk, messagebox
last=None
A={
'Readiness':[('Run All Readiness Checks','nexos-release-readiness-run-all'),('Release Readiness Report','nexos-release-readiness-report'),('Final Smoke Test','nexos-final-smoke-test'),('Desktop Readiness Report','nexos-desktop-readiness-report')],
'Build Tools':[('ISO Doctor','nexos-iso-doctor-gui'),('Build Fix Pass','nexos-build-fix-pass-gui'),('Build Validation','nexos-build-validation-report-gui'),('Open Reports','xdg-open ~/NexOS/Reports')],
'Desktop Finish':[('Desktop UX Final Pass','nexos-desktop-ux-final-center'),('App/Icon Validation','nexos-app-icon-validation-center'),('Desktop Shell Center','nexos-desktop-shell-center'),('Personalization','nexos-personalization-center')],
'Core Hubs':[('Control Panel','nexos-control-panel'),('Action Center','nexos-action-center'),('Security Center','nexos-security-center'),('Network Center','nexos-network-center')]
}
def run(c,show=True):
    global last
    e=c.split()[0]
    if not shutil.which(e):
        messagebox.showwarning('NexOS Release Readiness',f'{e} is not installed.'); return
    p=subprocess.run(c.split(),text=True,capture_output=True) if show and not c.endswith('-gui') and not c.startswith('xdg-open') else None
    if p:
        last=(p.stdout.strip().splitlines() or [''])[0]
        txt.delete('1.0','end')
        if last and Path(last).exists(): txt.insert('1.0',Path(last).read_text(errors='ignore'))
        else: txt.insert('1.0',p.stdout+p.stderr)
    else:
        subprocess.Popen(c.split(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
def refresh_latest():
    txt.delete('1.0','end')
    reports=sorted((Path.home()/'NexOS/Reports').glob('*'),key=lambda p:p.stat().st_mtime if p.exists() else 0,reverse=True)
    txt.insert('1.0','Latest NexOS reports:\n\n'+'\n'.join(str(p) for p in reports[:80]))
r=tk.Tk(); r.title('NexOS Release Readiness Center'); r.geometry('1100x760'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Release Readiness Center',bg='#07111f',fg='#e8f7ff',font=('Sans',31,'bold')).pack(anchor='w',padx=24,pady=(20,4))
tk.Label(r,text='One hub to decide if this ISO is ready: ISO Doctor, Build Fix, Build Validation, Final Smoke, Desktop UX, App/Icon checks and reports.',bg='#07111f',fg='#9bd5ff',wraplength=980,justify='left').pack(anchor='w',padx=24,pady=(0,12))
nb=ttk.Notebook(r); nb.pack(fill='x',padx=18,pady=8)
for cat,items in A.items():
    f=tk.Frame(nb,bg='#07111f',padx=14,pady=14); nb.add(f,text=cat)
    for i,(n,c) in enumerate(items): tk.Button(f,text=n,command=lambda x=c:run(x),bg='#0ea5e9' if i==0 else '#1f2937',fg='white' if i==0 else '#e8f7ff',activebackground='#0ea5e9',relief='flat',padx=14,pady=14,font=('Sans',11,'bold')).grid(row=i//2,column=i%2,padx=8,pady=8,sticky='ew'); f.grid_columnconfigure(i%2,weight=1)
bar=tk.Frame(r,bg='#07111f'); bar.pack(fill='x',padx=24,pady=6)
tk.Button(bar,text='Refresh Latest Reports',command=refresh_latest,bg='#1f2937',fg='#e8f7ff',relief='flat',padx=14,pady=10).pack(side='left',padx=4)
txt=tk.Text(r,bg='#0d172b',fg='#e8f7ff',insertbackground='#e8f7ff',relief='flat',font=('DejaVu Sans Mono',9)); txt.pack(fill='both',expand=True,padx=24,pady=12)
refresh_latest(); r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-release-readiness-center
for spec in "nexos-release-readiness-center|NexOS Release Readiness Center|System;Development;" "nexos-release-readiness-report|NexOS Release Readiness Report|System;Development;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-release-readiness.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-control-panel ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-control-panel'); s=p.read_text()
needle='["Final Smoke Test", "nexos-final-smoke-test-center", "One-click ISO readiness checks"],'
if 'nexos-release-readiness-center' not in s:
    s=s.replace(needle, needle+'\n    ["Release Readiness", "nexos-release-readiness-center", "All release checks in one hub"],')
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-control-panel; fi
if [[ -f /usr/local/bin/nexos-action-center ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-action-center'); s=p.read_text()
if "('Release','nexos-release-readiness-center')" not in s:
    s=s.replace("('Smoke Test','nexos-final-smoke-test-center')", "('Smoke Test','nexos-final-smoke-test-center'),('Release','nexos-release-readiness-center')")
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-action-center; fi
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-release-readiness-center' not in s: p.write_text(s.replace('\n]', '\n    ("Release", ["nexos-release-readiness-center"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('release readiness','nexos-release-readiness-center','NexOS Release Readiness Center'),('is iso ready','nexos-release-readiness-report','NexOS Release Readiness Report'),('run release checks','nexos-release-readiness-run-all','Run Release Readiness Checks')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Release Readiness Center:
- Adds one hub for ISO Doctor, Build Fix Pass, Build Validation, Final Smoke Test, Desktop UX Final Pass, App/Icon Validation, release readiness reports, run-all readiness checks, Control Panel integration, Action Center integration, dock/menu entries, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/510-nexos-release-readiness-center.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/510-nexos-release-readiness-center.hook.chroot"
success "Injected NexOS Release Readiness Center for $NEXOS_EDITION."
