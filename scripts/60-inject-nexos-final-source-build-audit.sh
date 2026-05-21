#!/usr/bin/env bash
# NexOS Final Source Build Audit: repo-side audit for workflow YAML, shell syntax, heredocs, injector wiring, package risks, and embedded Python risks.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/93-nexos-final-source-build-audit.list.chroot" <<'PKGS'
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
shellcheck
python3-yaml
PKGS
cat > "$LB_CONFIG_DIR/hooks/normal/520-nexos-final-source-build-audit.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin bash coreutils findutils grep sed jq shellcheck python3-yaml; do install_if_available "$p"; done
mkdir -p /opt/nexos/final-source-audit "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/NexOS/Reports"
cat > "$icon_dir/nexos-final-source-audit.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><path d="M33 31h48l15 15v51H33z" fill="none" stroke="#e8f7ff" stroke-width="7" stroke-linejoin="round"/><path d="M80 31v17h16" fill="none" stroke="#38bdf8" stroke-width="7" stroke-linejoin="round"/><path d="M45 66h37M45 82h27" stroke="#22c55e" stroke-width="6" stroke-linecap="round"/><circle cx="91" cy="89" r="9" fill="none" stroke="#38bdf8" stroke-width="6"/></svg>
SVG
cat > /usr/local/bin/nexos-final-source-build-audit <<'PY'
#!/usr/bin/env python3
import ast, os, re, shutil, subprocess, sys, time
from pathlib import Path
root=Path.cwd()
reports=Path.home()/"NexOS/Reports"; reports.mkdir(parents=True, exist_ok=True)
out=reports/f"final-source-build-audit-{time.strftime('%Y%m%d-%H%M%S')}.txt"
issues=[]; warnings=[]; passes=[]
def ok(msg): passes.append(msg)
def warn(msg): warnings.append(msg)
def issue(msg): issues.append(msg)
def read(p):
    try: return Path(p).read_text(errors='ignore')
    except Exception: return ''
def run(cmd, cwd=None):
    try: return subprocess.run(cmd, shell=True, text=True, cwd=cwd, capture_output=True, timeout=30)
    except Exception as e:
        class R: returncode=99; stdout=''; stderr=str(e)
        return R()
source_mode=(root/'scripts').is_dir()
if not source_mode:
    warn('No NexOS source tree detected. Run from repo root for full audit; runtime checks only were performed.')
else:
    ok(f'Source tree detected: {root}')
    # Workflow YAML syntax check.
    wf=root/'.github/workflows/build-nexos-iso.yml'
    if wf.exists():
        txt=read(wf)
        try:
            import yaml
            yaml.safe_load(txt)
            ok('GitHub workflow YAML parses with PyYAML')
        except Exception as e:
            issue(f'Workflow YAML parse failed: {e}')
        for marker in ['nexos-build-validation-report.txt','nexos-final-smoke-source-report.txt','nexos-release-readiness-source-report.txt','build/logs/**']:
            (ok if marker in txt else warn)(f'Workflow marker {marker}: ' + ('present' if marker in txt else 'missing'))
    else:
        issue('Missing .github/workflows/build-nexos-iso.yml')
    # Shell syntax for all scripts.
    syntax_failed=0
    for sh in sorted((root/'scripts').glob('*.sh')):
        p=run(f'bash -n {sh}')
        if p.returncode:
            issue(f'bash -n failed: {sh.name}: {(p.stderr or p.stdout).strip()}')
            syntax_failed+=1
    if syntax_failed==0: ok('All scripts/*.sh passed bash -n')
    # Late injector wiring.
    safety=read(root/'scripts/19-fix-nexos-package-lists.sh')
    if not safety:
        issue('Missing or unreadable scripts/19-fix-nexos-package-lists.sh')
    else:
        missing=[]
        for inj in sorted((root/'scripts').glob('*-inject-nexos-*.sh')):
            m=re.match(r'(\d+)-', inj.name)
            if m and int(m.group(1))>=27 and inj.name not in safety:
                missing.append(inj.name)
        if missing:
            for x in missing: issue(f'Late injector not wired in safety pass: {x}')
        else: ok('All existing late injectors are wired in package safety pass')
    # Heredoc balance and common markers.
    for inj in sorted((root/'scripts').glob('*-inject-nexos-*.sh')):
        txt=read(inj)
        for tag in ['HOOK','PY','BASH','DESKTOP','SVG','PKGS']:
            starts=txt.count("<<'"+tag+"'") + txt.count('<<'+tag)
            if starts and txt.count('\n'+tag+'\n') < starts:
                issue(f'Possible heredoc terminator mismatch in {inj.name}: {tag}')
        if 'chmod 0755' not in txt: warn(f'No chmod marker found in injector: {inj.name}')
        if 'success ' not in txt: warn(f'No success marker found in injector: {inj.name}')
    # Embedded Python ast parsing for heredocs where practical.
    py_blocks=0; py_bad=0
    for inj in sorted((root/'scripts').glob('*-inject-nexos-*.sh')):
        txt=read(inj)
        for match in re.finditer(r"<<'PY'\n(.*?)\nPY", txt, flags=re.S):
            py_blocks+=1
            try: ast.parse(match.group(1))
            except Exception as e:
                py_bad+=1; issue(f'Embedded Python parse failed in {inj.name}: {e}')
    if py_blocks: ok(f'Embedded Python blocks parsed: {py_blocks-py_bad}/{py_blocks}')
    # Package risk scan.
    hard='\n'.join(read(p) for p in (root/'config/package-lists').glob('*.list.chroot')) if (root/'config/package-lists').exists() else ''
    risks=[('grub-pc','grub-efi-amd64'),('pipewire-pulse','pulseaudio'),('network-manager','wicd')]
    for a,b in risks:
        if re.search(rf'^\s*{re.escape(a)}\s*$',hard,re.M) and re.search(rf'^\s*{re.escape(b)}\s*$',hard,re.M):
            warn(f'Potential package conflict in hard package lists: {a} + {b}')
    # Desktop/app icon generation scan from source.
    desktop_count=sum(read(p).count('[Desktop Entry]') for p in (root/'scripts').glob('*-inject-nexos-*.sh'))
    command_count=sum(read(p).count('cat > /usr/local/bin/nexos-') for p in (root/'scripts').glob('*-inject-nexos-*.sh'))
    ok(f'Source generated desktop entries detected: {desktop_count}')
    ok(f'Source generated NexOS command heredocs detected: {command_count}')
# Runtime checks.
runtime_cmds=list(Path('/usr/local/bin').glob('nexos-*'))
runtime_apps=list(Path('/usr/share/applications').glob('nexos-*.desktop'))
ok(f'Runtime NexOS commands visible: {len(runtime_cmds)}')
ok(f'Runtime NexOS desktop apps visible: {len(runtime_apps)}')
with out.open('w') as f:
    f.write('NexOS Final Source Build Audit\n==============================\n')
    f.write(time.ctime()+'\n\n')
    f.write(f'Summary: {len(issues)} issue(s), {len(warnings)} warning(s), {len(passes)} pass/info item(s)\n\n')
    for title,rows in [('ISSUES',issues),('WARNINGS',warnings),('PASS_INFO',passes)]:
        f.write(title+'\n'+'-'*len(title)+'\n')
        f.write('\n'.join('- '+x for x in rows) if rows else '- none')
        f.write('\n\n')
print(out)
if issues: sys.exit(2)
PY
chmod 0755 /usr/local/bin/nexos-final-source-build-audit
cat > /usr/local/bin/nexos-final-source-build-audit-gui <<'PY'
#!/usr/bin/env python3
import subprocess, tkinter as tk
from pathlib import Path
last=None
def run_audit():
    global last
    p=subprocess.run(['nexos-final-source-build-audit'], text=True, capture_output=True)
    last=(p.stdout.strip().splitlines() or [''])[0]
    txt.delete('1.0','end')
    if last and Path(last).exists(): txt.insert('1.0', Path(last).read_text(errors='ignore'))
    else: txt.insert('1.0', p.stdout+p.stderr)
def open_reports(): subprocess.Popen(['xdg-open', str(Path.home()/'NexOS/Reports')])
r=tk.Tk(); r.title('NexOS Final Source Build Audit'); r.geometry('1080x720'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Final Source Build Audit',bg='#07111f',fg='#e8f7ff',font=('Sans',31,'bold')).pack(anchor='w',padx=24,pady=(20,4))
tk.Label(r,text='Audits workflow YAML, shell syntax, heredocs, injector wiring, package risks, embedded Python, and runtime NexOS app visibility.',bg='#07111f',fg='#9bd5ff',wraplength=980,justify='left').pack(anchor='w',padx=24,pady=(0,12))
bar=tk.Frame(r,bg='#07111f'); bar.pack(fill='x',padx=24,pady=8)
tk.Button(bar,text='Run Audit',command=run_audit,bg='#0ea5e9',fg='white',relief='flat',padx=14,pady=10).pack(side='left',padx=4)
tk.Button(bar,text='Open Reports',command=open_reports,bg='#1f2937',fg='#e8f7ff',relief='flat',padx=14,pady=10).pack(side='left',padx=4)
txt=tk.Text(r,bg='#0d172b',fg='#e8f7ff',insertbackground='#e8f7ff',relief='flat',font=('DejaVu Sans Mono',9)); txt.pack(fill='both',expand=True,padx=24,pady=12)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-final-source-build-audit-gui
for spec in "nexos-final-source-build-audit-gui|NexOS Final Source Build Audit|System;Development;" "nexos-final-source-build-audit|NexOS Final Source Build Audit CLI|System;Development;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-final-source-audit.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-control-panel ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-control-panel'); s=p.read_text()
needle='["Release Readiness", "nexos-release-readiness-center", "All release checks in one hub"],'
if 'nexos-final-source-build-audit-gui' not in s:
    s=s.replace(needle, needle+'\n    ["Source Audit", "nexos-final-source-build-audit-gui", "Workflow, script and source audit"],')
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-control-panel; fi
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-final-source-build-audit-gui' not in s: p.write_text(s.replace('\n]', '\n    ("Audit", ["nexos-final-source-build-audit-gui"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('source audit','nexos-final-source-build-audit-gui','NexOS Final Source Build Audit'),('final source audit','nexos-final-source-build-audit-gui','NexOS Final Source Build Audit'),('run source audit','nexos-final-source-build-audit','Run Final Source Audit')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Final Source Build Audit:
- Adds final repo/source audit for workflow YAML syntax, shell syntax, injector wiring, heredoc risks, package conflicts, embedded Python parsing, runtime app visibility, reports, Control Panel integration, dock/menu entries, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/520-nexos-final-source-build-audit.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/520-nexos-final-source-build-audit.hook.chroot"
success "Injected NexOS Final Source Build Audit for $NEXOS_EDITION."
