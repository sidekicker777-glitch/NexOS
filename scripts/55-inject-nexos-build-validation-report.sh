#!/usr/bin/env bash
# NexOS Build Validation Report: feature/injector/package/app manifest reporting for ISO builds.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/88-nexos-build-validation-report.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
jq
coreutils
findutils
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/470-nexos-build-validation-report.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin jq coreutils findutils; do install_if_available "$p"; done
mkdir -p /opt/nexos/build-validation "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/NexOS/Reports"
cat > "$icon_dir/nexos-build-validation.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><path d="M34 31h48l14 14v52H34z" fill="none" stroke="#e8f7ff" stroke-width="7" stroke-linejoin="round"/><path d="M80 31v17h17" fill="none" stroke="#22c55e" stroke-width="7" stroke-linejoin="round"/><path d="M47 62h35M47 77h35M47 92h22" stroke="#38bdf8" stroke-width="6" stroke-linecap="round"/></svg>
SVG
cat > /usr/local/bin/nexos-build-validation-report <<'PY'
#!/usr/bin/env python3
import json, os, re, subprocess, sys, time
from pathlib import Path
home=Path.home(); reports=home/'NexOS/Reports'; reports.mkdir(parents=True,exist_ok=True)
out=reports/f'build-validation-{time.strftime("%Y%m%d-%H%M%S")}.txt'
root=Path.cwd(); source_mode=(root/'scripts').is_dir()
def read(p):
    try: return Path(p).read_text(errors='ignore')
    except Exception: return ''
def cmd(c):
    try: return subprocess.check_output(c,shell=True,text=True,stderr=subprocess.STDOUT,timeout=20)
    except Exception as e: return str(e)
lines=[]
add=lines.append
add('NexOS Build Validation Report')
add('=============================')
add(time.ctime())
add('')
if source_mode:
    add(f'Source root: {root}')
    injectors=sorted((root/'scripts').glob('*inject-nexos-*.sh'))
    add(f'Injector scripts: {len(injectors)}')
    safety=read(root/'scripts/19-fix-nexos-package-lists.sh')
    add('')
    add('Injectors')
    add('---------')
    for inj in injectors:
        txt=read(inj)
        hook=re.search(r'hooks/normal/([^" ]+)',txt)
        plist=re.search(r'package-lists/([^" ]+)',txt)
        wired='yes' if inj.name in safety else 'NO'
        add(f'- {inj.name} | wired={wired} | hook={hook.group(1) if hook else "unknown"} | package_list={plist.group(1) if plist else "unknown"}')
    add('')
    add('Generated feature map markers')
    add('-----------------------------')
    for inj in injectors:
        txt=read(inj)
        m=re.search(r'\n([^\n]*NexOS[^\n]*):\n- Adds ([^\n]+)',txt)
        if m: add(f'- {m.group(1).strip()}: {m.group(2).strip()}')
    add('')
    add('Package lists in source')
    add('-----------------------')
    for p in sorted((root/'config/package-lists').glob('*.list.chroot')) if (root/'config/package-lists').exists() else []:
        pkgs=[x.strip() for x in read(p).splitlines() if x.strip() and not x.strip().startswith('#')]
        add(f'- {p.name}: {len(pkgs)} hard packages')
    removed=root/'config/nexos-removed-optional-packages.txt'
    if removed.exists():
        add('')
        add('Packages moved to optional')
        add('--------------------------')
        add(read(removed) or 'none')
else:
    add('Source tree not detected. Runtime installed ISO report only.')
add('')
add('Installed NexOS commands')
add('------------------------')
for p in sorted(Path('/usr/local/bin').glob('nexos-*')):
    add(f'- {p.name}')
add('')
add('Installed NexOS desktop apps')
add('----------------------------')
for p in sorted(Path('/usr/share/applications').glob('nexos-*.desktop')):
    txt=read(p); name=re.search(r'^Name=(.*)$',txt,re.M); exe=re.search(r'^Exec=(.*)$',txt,re.M); icon=re.search(r'^Icon=(.*)$',txt,re.M)
    add(f'- {name.group(1) if name else p.stem} | Exec={exe.group(1) if exe else "missing"} | Icon={icon.group(1) if icon else "missing"}')
add('')
add('Runtime app map')
add('---------------')
add(read('/usr/share/nexos/app-map.txt') or 'missing')
out.write_text('\n'.join(lines)+'\n')
print(out)
PY
chmod 0755 /usr/local/bin/nexos-build-validation-report
cat > /usr/local/bin/nexos-build-validation-report-gui <<'PY'
#!/usr/bin/env python3
import subprocess, tkinter as tk
from pathlib import Path
last=None
def run_report():
    global last
    p=subprocess.run(['nexos-build-validation-report'],text=True,capture_output=True)
    last=(p.stdout.strip().splitlines() or [''])[0]
    txt.delete('1.0','end')
    if last and Path(last).exists(): txt.insert('1.0',Path(last).read_text(errors='ignore'))
    else: txt.insert('1.0',p.stdout+p.stderr)
def open_reports(): subprocess.Popen(['xdg-open',str(Path.home()/'NexOS/Reports')])
r=tk.Tk(); r.title('NexOS Build Validation Report'); r.geometry('1080x720'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Build Validation Report',bg='#07111f',fg='#e8f7ff',font=('Sans',31,'bold')).pack(anchor='w',padx=24,pady=(20,4))
tk.Label(r,text='Lists included features, injectors, package lists, optional moves, installed tools and expected ISO apps.',bg='#07111f',fg='#9bd5ff').pack(anchor='w',padx=24,pady=(0,12))
bar=tk.Frame(r,bg='#07111f'); bar.pack(fill='x',padx=24,pady=8)
tk.Button(bar,text='Generate Report',command=run_report,bg='#0ea5e9',fg='white',relief='flat',padx=14,pady=10).pack(side='left',padx=4)
tk.Button(bar,text='Open Reports',command=open_reports,bg='#1f2937',fg='#e8f7ff',relief='flat',padx=14,pady=10).pack(side='left',padx=4)
txt=tk.Text(r,bg='#0d172b',fg='#e8f7ff',insertbackground='#e8f7ff',relief='flat',font=('DejaVu Sans Mono',9)); txt.pack(fill='both',expand=True,padx=24,pady=12)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-build-validation-report-gui
for spec in "nexos-build-validation-report-gui|NexOS Build Validation Report|System;Development;" "nexos-build-validation-report|NexOS Build Validation Report CLI|System;Development;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-build-validation.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-control-panel ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-control-panel'); s=p.read_text()
needle='["Build Fix Pass", "nexos-build-fix-pass-gui", "Patch common source build blockers"],'
if 'nexos-build-validation-report-gui' not in s:
    s=s.replace(needle, needle+'\n    ["Build Validation", "nexos-build-validation-report-gui", "Included feature and app report"],')
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-control-panel; fi
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-build-validation-report-gui' not in s: p.write_text(s.replace('\n]', '\n    ("Validate", ["nexos-build-validation-report-gui"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('build validation','nexos-build-validation-report-gui','NexOS Build Validation Report'),('feature report','nexos-build-validation-report-gui','NexOS Build Validation Report'),('included apps report','nexos-build-validation-report-gui','NexOS Build Validation Report')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Build Validation Report:
- Adds feature/injector/package/app manifest reporting for ISO builds, expected app/tool list, optional package notes, Control Panel integration, dock/menu entries, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/470-nexos-build-validation-report.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/470-nexos-build-validation-report.hook.chroot"
success "Injected NexOS Build Validation Report for $NEXOS_EDITION."
