#!/usr/bin/env bash
# NexOS Build Health / ISO Doctor: pre-build scanner for injectors, hooks, package lists, desktop files, icons, and build risks.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/86-nexos-iso-doctor.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
shellcheck
python3-yaml
jq
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/450-nexos-iso-doctor.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin shellcheck python3-yaml jq; do install_if_available "$p"; done
mkdir -p /opt/nexos/iso-doctor "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/NexOS/Reports" "$home_dir/.config/nexos/iso-doctor"
cat > "$icon_dir/nexos-iso-doctor.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><path d="M64 25l34 16v24c0 25-15 43-34 53-19-10-34-28-34-53V41z" fill="none" stroke="#e8f7ff" stroke-width="7"/><path d="M48 70l10 10 24-30" fill="none" stroke="#22c55e" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/><circle cx="91" cy="35" r="7" fill="#38bdf8"/></svg>
SVG
cat > /usr/local/bin/nexos-iso-doctor <<'PY'
#!/usr/bin/env python3
import os, re, subprocess, sys, time
from pathlib import Path
ROOT=Path.cwd()
if (ROOT/'scripts').exists() and (ROOT/'config').exists(): project=ROOT
else:
    # Inside installed ISO, only runtime checks are possible.
    project=None
REPORT_DIR=Path.home()/'NexOS/Reports'; REPORT_DIR.mkdir(parents=True,exist_ok=True)
out=REPORT_DIR/f'iso-doctor-{time.strftime("%Y%m%d-%H%M%S")}.txt'
issues=[]; warnings=[]; info=[]
def add(level,msg):
    {'ISSUE':issues,'WARN':warnings,'INFO':info}[level].append(msg)
def read(p):
    try: return Path(p).read_text(errors='ignore')
    except Exception: return ''
def sh(cmd, cwd=None):
    try: return subprocess.check_output(cmd,shell=True,text=True,stderr=subprocess.STDOUT,cwd=cwd,timeout=20)
    except Exception as e: return str(e)
if project:
    scripts=project/'scripts'; config=project/'config'; lb=config
    injectors=sorted(scripts.glob('*inject-nexos-*.sh'))
    add('INFO',f'Project root: {project}')
    add('INFO',f'Injector scripts found: {len(injectors)}')
    safety=scripts/'19-fix-nexos-package-lists.sh'; safety_txt=read(safety)
    for inj in injectors:
        if inj.name not in safety_txt:
            add('ISSUE',f'Injector not wired in safety pass: {inj.name}')
        txt=read(inj)
        hook_match=re.search(r'cat > "\$LB_CONFIG_DIR/hooks/normal/([^"$]+)"', txt)
        pkg_match=re.search(r'cat > "\$LB_CONFIG_DIR/package-lists/([^"$]+)"', txt)
        if not hook_match: add('WARN',f'No normal hook heredoc detected: {inj.name}')
        if not pkg_match: add('WARN',f'No package list heredoc detected: {inj.name}')
        if 'chmod 0755' not in txt: add('WARN',f'No chmod marker detected: {inj.name}')
        if 'app_catalog.json' not in txt and int(re.match(r'(\d+)',inj.name).group(1) or 0) >= 27:
            add('WARN',f'No AI catalog integration detected: {inj.name}')
    pkg_lists=list((config/'package-lists').glob('*.list.chroot')) if (config/'package-lists').exists() else []
    add('INFO',f'Existing package lists in repo: {len(pkg_lists)}')
    bad_pairs=[('grub-pc','grub-efi-amd64'),('pipewire-pulse','pulseaudio')]
    all_pkg='\n'.join(read(p) for p in pkg_lists)
    for a,b in bad_pairs:
        if re.search(rf'^\s*{re.escape(a)}\s*$',all_pkg,re.M) and re.search(rf'^\s*{re.escape(b)}\s*$',all_pkg,re.M):
            add('ISSUE',f'Conflicting packages in hard lists: {a} + {b}')
    for p in scripts.glob('*.sh'):
        txt=read(p)
        if '\r\n' in txt: add('ISSUE',f'Windows CRLF line endings: {p}')
        if txt and not txt.startswith('#!'): add('WARN',f'Missing shebang: {p.name}')
    shellcheck=sh('command -v shellcheck >/dev/null && shellcheck scripts/*.sh || true', project)
    if shellcheck.strip(): add('WARN','Shellcheck output exists; inspect report section.')
else:
    add('INFO','No source tree detected. Running installed-system checks only.')
# Runtime/installed checks
for d in ['/usr/local/bin','/usr/share/applications','/usr/share/icons/hicolor/scalable/apps']:
    p=Path(d)
    add('INFO',f'{d}: {len(list(p.glob("nexos-*"))) if p.exists() else 0} NexOS entries')
for desktop in Path('/usr/share/applications').glob('nexos-*.desktop'):
    txt=read(desktop)
    name=re.search(r'^Name=(.*)$',txt,re.M); exe=re.search(r'^Exec=(.*)$',txt,re.M); icon=re.search(r'^Icon=(.*)$',txt,re.M)
    if not name: add('WARN',f'Desktop file missing Name: {desktop}')
    if not exe: add('WARN',f'Desktop file missing Exec: {desktop}')
    if exe:
        cmd=exe.group(1).split()[0]
        if not (Path('/usr/local/bin')/cmd).exists() and not Path(cmd).exists(): add('WARN',f'Desktop Exec may be missing: {desktop.name} -> {cmd}')
    if icon and icon.group(1).startswith('/') and not Path(icon.group(1)).exists(): add('WARN',f'Desktop Icon missing: {desktop.name} -> {icon.group(1)}')
with out.open('w') as f:
    f.write('NexOS ISO Doctor Report\n========================\n')
    f.write(time.ctime()+'\n\n')
    f.write(f'Summary: {len(issues)} issue(s), {len(warnings)} warning(s), {len(info)} info item(s)\n\n')
    for title,rows in [('ISSUES',issues),('WARNINGS',warnings),('INFO',info)]:
        f.write(title+'\n'+'-'*len(title)+'\n')
        if rows:
            for r in rows: f.write(f'- {r}\n')
        else: f.write('- none\n')
        f.write('\n')
    if project:
        f.write('Shellcheck output\n-----------------\n')
        f.write(shellcheck if shellcheck.strip() else 'none\n')
print(out)
if issues: sys.exit(2)
PY
chmod 0755 /usr/local/bin/nexos-iso-doctor
cat > /usr/local/bin/nexos-iso-doctor-gui <<'PY'
#!/usr/bin/env python3
import shutil, subprocess, tkinter as tk
from pathlib import Path
from tkinter import messagebox
last=None
def run_scan():
    global last
    try:
        p=subprocess.run(['nexos-iso-doctor'],text=True,capture_output=True,timeout=60)
        last=(p.stdout.strip().splitlines() or [''])[0]
        txt.delete('1.0','end')
        if last and Path(last).exists(): txt.insert('1.0',Path(last).read_text(errors='ignore'))
        else: txt.insert('1.0',p.stdout+p.stderr)
    except Exception as e: messagebox.showwarning('NexOS ISO Doctor',str(e))
def open_report():
    if last and Path(last).exists(): subprocess.Popen(['xdg-open',last])
    else: subprocess.Popen(['xdg-open',str(Path.home()/'NexOS/Reports')])
def open_reports(): subprocess.Popen(['xdg-open',str(Path.home()/'NexOS/Reports')])
r=tk.Tk(); r.title('NexOS ISO Doctor'); r.geometry('1040x720'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS ISO Doctor',bg='#07111f',fg='#e8f7ff',font=('Sans',32,'bold')).pack(anchor='w',padx=24,pady=(20,4))
tk.Label(r,text='Pre-build health scanner for injectors, hooks, package lists, desktop files, icons and build-risk packages.',bg='#07111f',fg='#9bd5ff',wraplength=940,justify='left').pack(anchor='w',padx=24,pady=(0,10))
bar=tk.Frame(r,bg='#07111f'); bar.pack(fill='x',padx=24,pady=8)
for n,c,bg in [('Run Scan',run_scan,'#0ea5e9'),('Open Last Report',open_report,'#1f2937'),('Open Reports Folder',open_reports,'#1f2937')]: tk.Button(bar,text=n,command=c,bg=bg,fg='white' if bg=='#0ea5e9' else '#e8f7ff',relief='flat',padx=14,pady=10).pack(side='left',padx=4)
txt=tk.Text(r,bg='#0d172b',fg='#e8f7ff',insertbackground='#e8f7ff',relief='flat',font=('DejaVu Sans Mono',9)); txt.pack(fill='both',expand=True,padx=24,pady=12)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-iso-doctor-gui
for spec in "nexos-iso-doctor-gui|NexOS ISO Doctor|System;Development;" "nexos-iso-doctor|NexOS ISO Doctor CLI|System;Development;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-iso-doctor.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-control-panel ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-control-panel'); s=p.read_text()
needle='["Update Center", "nexos-update-center", "Updates and repair tools"],'
if 'nexos-iso-doctor-gui' not in s:
    s=s.replace(needle, needle+'\n    ["ISO Doctor", "nexos-iso-doctor-gui", "Pre-build health scanner"],')
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-control-panel; fi
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-iso-doctor-gui' not in s: p.write_text(s.replace('\n]', '\n    ("Doctor", ["nexos-iso-doctor-gui"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('iso doctor','nexos-iso-doctor-gui','NexOS ISO Doctor'),('build health','nexos-iso-doctor-gui','NexOS ISO Doctor'),('run iso scan','x-terminal-emulator -e nexos-iso-doctor','Run ISO Doctor')]:
    d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS ISO Doctor:
- Adds build health scanner for missing injector wiring, hook/package heredocs, conflict-risk package lists, shell script risks, desktop files, missing icons, reports, Control Panel integration, dock/menu entries, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/450-nexos-iso-doctor.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/450-nexos-iso-doctor.hook.chroot"
success "Injected NexOS ISO Doctor for $NEXOS_EDITION."
