#!/usr/bin/env bash
# NexOS App/Icon Validation Fix Pass: validates .desktop launchers, Exec commands, icons, trust markers, and app reports.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/89-nexos-app-icon-validation-fix-pass.list.chroot" <<'PKGS'
python3
python3-tk
xdg-utils
libnotify-bin
hicolor-icon-theme
desktop-file-utils
glib2.0-bin
findutils
coreutils
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/480-nexos-app-icon-validation-fix-pass.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin hicolor-icon-theme desktop-file-utils glib2.0-bin findutils coreutils; do install_if_available "$p"; done
mkdir -p /opt/nexos/app-icon-validation "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/NexOS/Reports"
cat > "$icon_dir/nexos-app-icon-validation.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><rect x="29" y="30" width="28" height="28" rx="7" fill="none" stroke="#e8f7ff" stroke-width="6"/><rect x="71" y="30" width="28" height="28" rx="7" fill="none" stroke="#22c55e" stroke-width="6"/><rect x="29" y="72" width="28" height="28" rx="7" fill="none" stroke="#22c55e" stroke-width="6"/><path d="M72 86l9 9 20-25" fill="none" stroke="#38bdf8" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/></svg>
SVG
cat > /usr/local/bin/nexos-app-icon-fix-pass <<'PY'
#!/usr/bin/env python3
import os, re, shutil, stat, subprocess, time
from pathlib import Path
HOME=Path.home(); REPORTS=HOME/'NexOS/Reports'; REPORTS.mkdir(parents=True,exist_ok=True)
REPORT=REPORTS/f'app-icon-validation-{time.strftime("%Y%m%d-%H%M%S")}.txt'
APP_DIRS=[Path('/usr/share/applications'), HOME/'.local/share/applications', HOME/'Desktop']
FALLBACK='/usr/share/icons/hicolor/scalable/apps/nexos-control-panel.svg'
changes=[]; warnings=[]; ok=[]
def read(p):
    try: return p.read_text(errors='ignore')
    except Exception: return ''
def write(p,s):
    p.write_text(s)
    try: os.chmod(p, os.stat(p).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    except Exception: pass
def get(txt,key):
    m=re.search(rf'^{re.escape(key)}=(.*)$',txt,re.M)
    return m.group(1).strip() if m else ''
def command_exists(cmd):
    if not cmd: return False
    first=cmd.split()[0].strip('"\'')
    if first.startswith('/'): return Path(first).exists()
    return shutil.which(first) is not None or (Path('/usr/local/bin')/first).exists()
def icon_exists(icon):
    if not icon: return False
    if icon.startswith('/'): return Path(icon).exists()
    candidates=[Path('/usr/share/icons/hicolor/scalable/apps')/(icon+'.svg'),Path('/usr/share/pixmaps')/(icon+'.png'),Path('/usr/share/pixmaps')/(icon+'.svg')]
    return any(p.exists() for p in candidates)
for d in APP_DIRS:
    if not d.exists(): continue
    for f in sorted(d.glob('nexos-*.desktop')):
        txt=read(f); orig=txt
        name=get(txt,'Name'); exe=get(txt,'Exec'); icon=get(txt,'Icon')
        if not name:
            txt+='\nName='+f.stem.replace('-',' ').title()+'\n'; changes.append(f'Added missing Name: {f}')
        if not exe:
            cmd=f.stem
            txt+='\nExec='+cmd+'\n'; exe=cmd; changes.append(f'Added missing Exec guess: {f} -> {cmd}')
        if exe and not command_exists(exe):
            warnings.append(f'Missing Exec command: {f.name} -> {exe}')
        if not icon or not icon_exists(icon):
            txt=re.sub(r'^Icon=.*$', 'Icon='+FALLBACK, txt, flags=re.M) if re.search(r'^Icon=',txt,re.M) else txt+'\nIcon='+FALLBACK+'\n'
            changes.append(f'Fixed missing icon: {f.name}')
        if 'Terminal=' not in txt:
            txt+='Terminal=false\n'; changes.append(f'Added Terminal=false: {f.name}')
        if 'Type=Application' not in txt:
            txt='[Desktop Entry]\nType=Application\n'+re.sub(r'^\[Desktop Entry\]\n?','',txt)
            changes.append(f'Ensured Desktop Entry header/type: {f.name}')
        if 'X-XFCE-Trusted=true' not in txt:
            txt+='X-XFCE-Trusted=true\n'; changes.append(f'Added XFCE trusted marker: {f.name}')
        if txt!=orig: write(f,txt)
        try:
            os.chmod(f, os.stat(f).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
        except Exception: pass
        try:
            subprocess.run(['gio','set',str(f),'metadata::trusted','true'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        except Exception: pass
        ok.append(f.name)
# refresh desktop database/icon cache if tools exist
for cmd in [['update-desktop-database','/usr/share/applications'],['gtk-update-icon-cache','-f','/usr/share/icons/hicolor']]:
    if shutil.which(cmd[0]): subprocess.run(cmd,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
with REPORT.open('w') as r:
    r.write('NexOS App/Icon Validation Fix Pass\n==================================\n')
    r.write(time.ctime()+'\n\n')
    r.write(f'Launchers scanned: {len(ok)}\nChanges applied: {len(changes)}\nWarnings: {len(warnings)}\n\n')
    r.write('CHANGES\n-------\n')
    r.write('\n'.join('- '+c for c in changes) if changes else '- none')
    r.write('\n\nWARNINGS\n--------\n')
    r.write('\n'.join('- '+w for w in warnings) if warnings else '- none')
    r.write('\n\nLAUNCHERS\n---------\n')
    r.write('\n'.join('- '+x for x in ok) if ok else '- none')
    r.write('\n')
print(REPORT)
PY
chmod 0755 /usr/local/bin/nexos-app-icon-fix-pass
cat > /usr/local/bin/nexos-app-icon-report <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
nexos-app-icon-fix-pass
BASH
chmod 0755 /usr/local/bin/nexos-app-icon-report
cat > /usr/local/bin/nexos-app-icon-validation-center <<'PY'
#!/usr/bin/env python3
import subprocess, tkinter as tk
from pathlib import Path
last=None
def run_fix():
    global last
    p=subprocess.run(['nexos-app-icon-fix-pass'],text=True,capture_output=True)
    last=(p.stdout.strip().splitlines() or [''])[0]
    txt.delete('1.0','end')
    if last and Path(last).exists(): txt.insert('1.0',Path(last).read_text(errors='ignore'))
    else: txt.insert('1.0',p.stdout+p.stderr)
def open_reports(): subprocess.Popen(['xdg-open',str(Path.home()/'NexOS/Reports')])
r=tk.Tk(); r.title('NexOS App/Icon Validation Center'); r.geometry('1040x700'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS App/Icon Validation Center',bg='#07111f',fg='#e8f7ff',font=('Sans',30,'bold')).pack(anchor='w',padx=24,pady=(20,4))
tk.Label(r,text='Fix broken NexOS launchers, missing icons, missing trusted markers, and bad desktop app entries.',bg='#07111f',fg='#9bd5ff').pack(anchor='w',padx=24,pady=(0,12))
bar=tk.Frame(r,bg='#07111f'); bar.pack(fill='x',padx=24,pady=8)
tk.Button(bar,text='Run Fix Pass',command=run_fix,bg='#0ea5e9',fg='white',relief='flat',padx=14,pady=10).pack(side='left',padx=4)
tk.Button(bar,text='Open Reports',command=open_reports,bg='#1f2937',fg='#e8f7ff',relief='flat',padx=14,pady=10).pack(side='left',padx=4)
txt=tk.Text(r,bg='#0d172b',fg='#e8f7ff',insertbackground='#e8f7ff',relief='flat',font=('DejaVu Sans Mono',9)); txt.pack(fill='both',expand=True,padx=24,pady=12)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-app-icon-validation-center
for spec in "nexos-app-icon-validation-center|NexOS App Icon Validation Center|System;Settings;" "nexos-app-icon-report|NexOS App Icon Report|System;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-app-icon-validation.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
cat > "$home_dir/.config/autostart/nexos-app-icon-fix-pass.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS App Icon Fix Pass
Exec=nexos-app-icon-fix-pass
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP
if [[ -f /usr/local/bin/nexos-control-panel ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-control-panel'); s=p.read_text()
needle='["Desktop Shell", "nexos-desktop-shell-center", "Shortcuts, panels and launcher polish"]'
if 'nexos-app-icon-validation-center' not in s:
    s=s.replace(needle, needle + ',\n    ["App Icons", "nexos-app-icon-validation-center", "Launcher and icon validation"]')
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-control-panel; fi
if [[ -f /usr/local/bin/nexos-action-center ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-action-center'); s=p.read_text()
if "('App Icons','nexos-app-icon-validation-center')" not in s:
    s=s.replace("('Desktop','nexos-desktop-shell-center')", "('Desktop','nexos-desktop-shell-center'),('App Icons','nexos-app-icon-validation-center')")
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-action-center; fi
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-app-icon-validation-center' not in s: p.write_text(s.replace('\n]', '\n    ("Icons", ["nexos-app-icon-validation-center"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('app icon validation','nexos-app-icon-validation-center','NexOS App Icon Validation Center'),('fix icons','nexos-app-icon-fix-pass','Fix NexOS Icons'),('launcher report','nexos-app-icon-report','NexOS App Icon Report')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS App/Icon Validation Fix Pass:
- Adds launcher validation, Exec checks, icon fallback repair, trusted marker repair, desktop database refresh, autostart validation, reports, Control Panel integration, Action Center integration, dock/menu entries, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/480-nexos-app-icon-validation-fix-pass.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/480-nexos-app-icon-validation-fix-pass.hook.chroot"
success "Injected NexOS App/Icon Validation Fix Pass for $NEXOS_EDITION."
