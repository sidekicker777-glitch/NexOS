#!/usr/bin/env bash
# NexOS Build Fix Pass: source-tree preflight fixer for common ISO build blockers before GitHub Actions runs.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/87-nexos-build-fix-pass.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
jq
shellcheck
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/460-nexos-build-fix-pass.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin jq shellcheck; do install_if_available "$p"; done
mkdir -p /opt/nexos/build-fix-pass "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/NexOS/Reports"
cat > "$icon_dir/nexos-build-fix-pass.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><path d="M35 75l17 17 42-50" fill="none" stroke="#22c55e" stroke-width="10" stroke-linecap="round" stroke-linejoin="round"/><path d="M30 37h68M30 52h48" stroke="#e8f7ff" stroke-width="6" stroke-linecap="round"/></svg>
SVG
cat > /usr/local/bin/nexos-build-fix-pass <<'PY'
#!/usr/bin/env python3
import os, re, stat, subprocess, sys, time
from pathlib import Path
root=Path.cwd()
if not (root/'scripts').is_dir():
    print('Run this from the NexOS repo root. Runtime ISO has no source tree to patch.')
    sys.exit(1)
reports=Path.home()/'NexOS/Reports'; reports.mkdir(parents=True,exist_ok=True)
report=reports/f'build-fix-pass-{time.strftime("%Y%m%d-%H%M%S")}.txt'
changes=[]; warnings=[]
def read(p):
    try: return Path(p).read_text(errors='ignore')
    except Exception: return ''
def write(p,s):
    Path(p).write_text(s)
    try: os.chmod(p, os.stat(p).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    except Exception: pass
scripts=root/'scripts'; config=root/'config'
safety=scripts/'19-fix-nexos-package-lists.sh'
safety_txt=read(safety)
# Wire any new injectors missing from safety pass.
for inj in sorted(scripts.glob('*inject-nexos-*.sh')):
    if inj.name not in safety_txt:
        safety_txt=safety_txt.replace('53-inject-nexos-iso-doctor.sh;', f'53-inject-nexos-iso-doctor.sh \\\n  {inj.name};')
        changes.append(f'Wired missing injector into safety pass: {inj.name}')
if safety.exists(): write(safety,safety_txt)
# Remove hard known conflict pairs from generated config package lists.
conflicts=[('grub-pc','grub-efi-amd64'),('pipewire-pulse','pulseaudio')]
for plist in (config/'package-lists').glob('*.list.chroot') if (config/'package-lists').exists() else []:
    txt=read(plist); orig=txt
    for a,b in conflicts:
        if re.search(rf'^\s*{a}\s*$',txt,re.M) and re.search(rf'^\s*{b}\s*$',txt,re.M):
            txt=re.sub(rf'^\s*{b}\s*$', f'# moved to optional hook due conflict: {b}', txt, flags=re.M)
            changes.append(f'Removed conflict from hard list {plist.name}: {b}')
    if txt!=orig: write(plist,txt)
# Basic script hygiene.
for sh in scripts.glob('*.sh'):
    txt=read(sh); orig=txt
    txt=txt.replace('\r\n','\n')
    if txt and not txt.startswith('#!'):
        txt='#!/usr/bin/env bash\n'+txt
        changes.append(f'Added shebang: {sh.name}')
    if 'set -Eeuo pipefail' not in txt.split('\n')[:8] and sh.name!='common.sh':
        txt=txt.replace('#!/usr/bin/env bash\n','#!/usr/bin/env bash\nset -Eeuo pipefail\n',1)
        changes.append(f'Added strict mode: {sh.name}')
    if txt!=orig: write(sh,txt)
# Detect common heredoc mistakes.
for inj in sorted(scripts.glob('*inject-nexos-*.sh')):
    txt=read(inj)
    if txt.count("<<'HOOK'") != txt.count('\nHOOK'):
        warnings.append(f'Possible HOOK heredoc mismatch: {inj.name}')
    if 'cat > "$LB_CONFIG_DIR/hooks/normal/' not in txt:
        warnings.append(f'No hook generation detected: {inj.name}')
    if 'cat > "$LB_CONFIG_DIR/package-lists/' not in txt:
        warnings.append(f'No package-list generation detected: {inj.name}')
# Desktop entry sanity from source text.
for inj in sorted(scripts.glob('*inject-nexos-*.sh')):
    txt=read(inj)
    if '.desktop' in txt and 'X-XFCE-Trusted=true' not in txt:
        warnings.append(f'Desktop entries may miss trusted marker: {inj.name}')
# Python syntax quick checks embedded rough extraction not safe; check standalone .py files only.
py_files=list(root.rglob('*.py'))
for py in py_files[:200]:
    p=subprocess.run([sys.executable,'-m','py_compile',str(py)],capture_output=True,text=True)
    if p.returncode: warnings.append(f'Python compile failed: {py}: {p.stderr.strip()}')
with report.open('w') as f:
    f.write('NexOS Build Fix Pass Report\n===========================\n')
    f.write(time.ctime()+'\n\n')
    f.write(f'Changes applied: {len(changes)}\nWarnings: {len(warnings)}\n\n')
    f.write('CHANGES\n-------\n')
    f.write('\n'.join('- '+c for c in changes) if changes else '- none')
    f.write('\n\nWARNINGS\n--------\n')
    f.write('\n'.join('- '+w for w in warnings) if warnings else '- none')
    f.write('\n')
print(report)
PY
chmod 0755 /usr/local/bin/nexos-build-fix-pass
cat > /usr/local/bin/nexos-build-fix-pass-gui <<'PY'
#!/usr/bin/env python3
import subprocess, tkinter as tk
from pathlib import Path
from tkinter import messagebox
last=None
def run_fix():
    global last
    p=subprocess.run(['nexos-build-fix-pass'],text=True,capture_output=True)
    last=(p.stdout.strip().splitlines() or [''])[0]
    txt.delete('1.0','end')
    if last and Path(last).exists(): txt.insert('1.0',Path(last).read_text(errors='ignore'))
    else: txt.insert('1.0',p.stdout+p.stderr)
def open_reports(): subprocess.Popen(['xdg-open',str(Path.home()/'NexOS/Reports')])
r=tk.Tk(); r.title('NexOS Build Fix Pass'); r.geometry('1040x700'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Build Fix Pass',bg='#07111f',fg='#e8f7ff',font=('Sans',32,'bold')).pack(anchor='w',padx=24,pady=(20,4))
tk.Label(r,text='Run from the NexOS repo root to patch common build blockers before GitHub ISO builds.',bg='#07111f',fg='#9bd5ff').pack(anchor='w',padx=24,pady=(0,12))
bar=tk.Frame(r,bg='#07111f'); bar.pack(fill='x',padx=24,pady=8)
tk.Button(bar,text='Run Fix Pass',command=run_fix,bg='#0ea5e9',fg='white',relief='flat',padx=14,pady=10).pack(side='left',padx=4)
tk.Button(bar,text='Open Reports',command=open_reports,bg='#1f2937',fg='#e8f7ff',relief='flat',padx=14,pady=10).pack(side='left',padx=4)
txt=tk.Text(r,bg='#0d172b',fg='#e8f7ff',insertbackground='#e8f7ff',relief='flat',font=('DejaVu Sans Mono',9)); txt.pack(fill='both',expand=True,padx=24,pady=12)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-build-fix-pass-gui
for spec in "nexos-build-fix-pass-gui|NexOS Build Fix Pass|System;Development;" "nexos-build-fix-pass|NexOS Build Fix Pass CLI|System;Development;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-build-fix-pass.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-control-panel ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-control-panel'); s=p.read_text()
needle='["ISO Doctor", "nexos-iso-doctor-gui", "Pre-build health scanner"],'
if 'nexos-build-fix-pass-gui' not in s:
    s=s.replace(needle, needle+'\n    ["Build Fix Pass", "nexos-build-fix-pass-gui", "Patch common source build blockers"],')
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-control-panel; fi
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-build-fix-pass-gui' not in s: p.write_text(s.replace('\n]', '\n    ("Fix Build", ["nexos-build-fix-pass-gui"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('build fix pass','nexos-build-fix-pass-gui','NexOS Build Fix Pass'),('fix iso build','nexos-build-fix-pass-gui','NexOS Build Fix Pass'),('run build fix','x-terminal-emulator -e nexos-build-fix-pass','Run Build Fix Pass')]:
    d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Build Fix Pass:
- Adds source-tree preflight fixer for missing injector wiring, known package conflicts, line endings, script hygiene, heredoc warnings, Python compile checks, reports, Control Panel integration, dock/menu entries, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/460-nexos-build-fix-pass.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/460-nexos-build-fix-pass.hook.chroot"
success "Injected NexOS Build Fix Pass for $NEXOS_EDITION."
