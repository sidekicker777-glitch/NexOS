#!/usr/bin/env bash
# NexOS Release Notes Pack: generates user-facing ISO release notes, included feature summaries, known issues and next steps.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
NEXOS_EDITION="${NEXOS_EDITION:-main}"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"
cat > "$LB_CONFIG_DIR/package-lists/94-nexos-release-notes-pack.list.chroot" <<'PKGS'
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
cat > "$LB_CONFIG_DIR/hooks/normal/530-nexos-release-notes-pack.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
install_if_available(){ local p="$1"; if apt-cache show "$p" >/dev/null 2>&1; then apt-get install -y --no-install-recommends "$p" || true; fi; }
apt-get update || true
for p in python3 python3-tk xdg-utils libnotify-bin bash coreutils findutils grep sed jq; do install_if_available "$p"; done
mkdir -p /opt/nexos/release-notes "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/NexOS/Reports" "$home_dir/NexOS/Release Notes"
cat > "$icon_dir/nexos-release-notes.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="8" y="8" width="112" height="112" rx="28" fill="#020617" stroke="#38bdf8" stroke-width="4"/><path d="M35 27h43l18 18v56H35z" fill="none" stroke="#e8f7ff" stroke-width="7" stroke-linejoin="round"/><path d="M78 27v20h18" fill="none" stroke="#22c55e" stroke-width="7" stroke-linejoin="round"/><path d="M48 61h34M48 77h34M48 93h20" stroke="#38bdf8" stroke-width="6" stroke-linecap="round"/></svg>
SVG
cat > /usr/local/bin/nexos-release-notes-generate <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
out="$HOME/NexOS/Release Notes/NexOS-release-notes-$(date +%Y%m%d-%H%M%S).md"
mkdir -p "$(dirname "$out")" "$HOME/NexOS/Reports"
{
echo "# NexOS Release Notes"
echo
echo "Generated: $(date)"
echo
echo "## What this ISO includes"
echo
echo "This NexOS build includes the main desktop shell, NexOS-branded desktop polish, Control Panel hubs, AI assistant integration hooks, build validation tools, release readiness tools, and the latest desktop/app/icon repair passes."
echo
echo "## Major NexOS hubs"
echo
for app in \
  nexos-control-panel "NexOS Control Panel" \
  nexos-action-center "Action Center" \
  nexos-settings "Settings" \
  nexos-personalization-center "Personalization Center" \
  nexos-network-center "Network Center" \
  nexos-security-center "Security Center" \
  nexos-power-center "Power Center" \
  nexos-update-center "Update Center" \
  nexos-driver-center "Driver Center" \
  nexos-backup-restore-center "Backup / Restore Center" \
  nexos-task-manager "Task Manager" \
  nexos-software-center "Software Center" \
  nexos-code-editor "Code Editor" \
  nexos-game-library "Game Library" \
  nexos-release-readiness-center "Release Readiness Center"; do
  if [[ -z "${cmd:-}" ]]; then cmd="$app"; else label="$app"; if command -v "$cmd" >/dev/null 2>&1; then echo "- ✅ $label ($cmd)"; else echo "- ⚠️ $label ($cmd) not detected in this runtime"; fi; unset cmd; fi
done
echo
echo "## Desktop UX improvements"
echo
cat <<'TXT'
- NexOS Desktop UX Final Pass runs a first-boot polish pipeline.
- App/Icon Validation repairs missing icons and trusted launcher markers.
- Desktop Shell Polish creates NexOS shortcuts and cleans duplicate Debian/XFCE launchers.
- Personalization Center adds NexOS themes, wallpapers, layout profiles and font helpers.
TXT
echo
echo "## Build and release tools"
echo
for cmd in nexos-iso-doctor nexos-build-fix-pass nexos-build-validation-report nexos-final-smoke-test nexos-release-readiness-report nexos-final-source-build-audit; do
  if command -v "$cmd" >/dev/null 2>&1; then echo "- ✅ $cmd"; else echo "- ⚠️ $cmd not detected"; fi
done
echo
echo "## AI assistant integration"
echo
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then
  echo "AI assistant app catalog detected. NexOS can route commands to installed NexOS tools where the assistant service is installed."
else
  echo "AI assistant catalog was not detected in this runtime. The build may still include assistant integration hooks in source."
fi
echo
echo "## Known issues to check after boot"
echo
cat <<'TXT'
- Verify GPU detection in Driver Center on real hardware and in VirtualBox/VMware.
- Verify the desktop panel placement and app icons after first login.
- Verify wake-word assistant behavior only after microphone permissions and assistant service are enabled.
- Verify emulator/BIOS folders only with legally supplied BIOS files.
- Verify the GitHub Actions artifact contains the ISO, SHA256 file and build/logs folder.
TXT
echo
echo "## Recommended first-run checks"
echo
cat <<'TXT'
1. Open NexOS Control Panel.
2. Run Desktop UX Final Pass.
3. Run App/Icon Validation Center.
4. Run Final Smoke Test.
5. Open Release Readiness Center.
6. Check Network Center, Security Center, Power Center and Driver Center.
7. Reboot once and confirm shortcuts/icons still look correct.
TXT
echo
echo "## Installed NexOS commands"
echo
find /usr/local/bin -maxdepth 1 -type f -executable -name 'nexos-*' -printf '- %f\n' 2>/dev/null | sort | head -400 || true
echo
echo "## Installed NexOS desktop launchers"
echo
find /usr/share/applications -maxdepth 1 -type f -name 'nexos-*.desktop' -printf '- %f\n' 2>/dev/null | sort | head -400 || true
echo
echo "## App map"
echo
if [[ -f /usr/share/nexos/app-map.txt ]]; then sed -n '1,260p' /usr/share/nexos/app-map.txt; else echo "No /usr/share/nexos/app-map.txt found."; fi
} > "$out"
cp "$out" "$HOME/NexOS/Reports/$(basename "$out")" 2>/dev/null || true
notify-send "NexOS Release Notes" "Release notes generated" 2>/dev/null || true
echo "$out"
BASH
chmod 0755 /usr/local/bin/nexos-release-notes-generate
cat > /usr/local/bin/nexos-release-notes-center <<'PY'
#!/usr/bin/env python3
import subprocess, tkinter as tk
from pathlib import Path
last=None
def generate():
    global last
    p=subprocess.run(['nexos-release-notes-generate'],text=True,capture_output=True)
    last=(p.stdout.strip().splitlines() or [''])[0]
    txt.delete('1.0','end')
    if last and Path(last).exists(): txt.insert('1.0',Path(last).read_text(errors='ignore'))
    else: txt.insert('1.0',p.stdout+p.stderr)
def open_notes(): subprocess.Popen(['xdg-open',str(Path.home()/'NexOS/Release Notes')])
def open_reports(): subprocess.Popen(['xdg-open',str(Path.home()/'NexOS/Reports')])
r=tk.Tk(); r.title('NexOS Release Notes Center'); r.geometry('1080x740'); r.configure(bg='#07111f')
tk.Label(r,text='NexOS Release Notes Center',bg='#07111f',fg='#e8f7ff',font=('Sans',31,'bold')).pack(anchor='w',padx=24,pady=(20,4))
tk.Label(r,text='Generate clear release notes showing what changed, what tools are included, known checks, and next steps after ISO build.',bg='#07111f',fg='#9bd5ff',wraplength=980,justify='left').pack(anchor='w',padx=24,pady=(0,12))
bar=tk.Frame(r,bg='#07111f'); bar.pack(fill='x',padx=24,pady=8)
for n,c,bg in [('Generate Release Notes',generate,'#0ea5e9'),('Open Release Notes',open_notes,'#1f2937'),('Open Reports',open_reports,'#1f2937')]: tk.Button(bar,text=n,command=c,bg=bg,fg='white' if bg=='#0ea5e9' else '#e8f7ff',relief='flat',padx=14,pady=10).pack(side='left',padx=4)
txt=tk.Text(r,bg='#0d172b',fg='#e8f7ff',insertbackground='#e8f7ff',relief='flat',font=('DejaVu Sans Mono',9)); txt.pack(fill='both',expand=True,padx=24,pady=12)
r.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-release-notes-center
for spec in "nexos-release-notes-center|NexOS Release Notes Center|System;Development;" "nexos-release-notes-generate|NexOS Release Notes Generator|System;Development;"; do
 IFS='|' read -r exec name cats <<< "$spec"
 cat > "/usr/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-release-notes.svg
Terminal=false
Categories=$cats
X-XFCE-Trusted=true
DESKTOP
 chmod 0755 "/usr/share/applications/$exec.desktop"
done
if [[ -f /usr/local/bin/nexos-control-panel ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-control-panel'); s=p.read_text()
needle='["Source Audit", "nexos-final-source-build-audit-gui", "Workflow, script and source audit"],'
if 'nexos-release-notes-center' not in s:
    s=s.replace(needle, needle+'\n    ["Release Notes", "nexos-release-notes-center", "Generate ISO change notes"],')
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-control-panel; fi
if [[ -f /usr/local/bin/nexos-action-center ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-action-center'); s=p.read_text()
if "('Release Notes','nexos-release-notes-center')" not in s:
    s=s.replace("('Release','nexos-release-readiness-center')", "('Release','nexos-release-readiness-center'),('Release Notes','nexos-release-notes-center')")
    p.write_text(s)
PY
chmod 0755 /usr/local/bin/nexos-action-center; fi
if [[ -f /usr/local/bin/nexos-dock ]]; then python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock'); s=p.read_text()
if 'nexos-release-notes-center' not in s: p.write_text(s.replace('\n]', '\n    ("Notes", ["nexos-release-notes-center"]),\n]', 1))
PY
chmod 0755 /usr/local/bin/nexos-dock; fi
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json'); d=json.loads(p.read_text())
for k,c,l in [('release notes','nexos-release-notes-center','NexOS Release Notes Center'),('generate release notes','nexos-release-notes-generate','Generate NexOS Release Notes'),('what changed','nexos-release-notes-center','NexOS Release Notes Center')]: d[k]={'label':l,'commands':[c],'permission':'app.open'}
p.write_text(json.dumps(d,indent=2))
PY
fi
cat >> /usr/share/nexos/app-map.txt <<'APPMAP'

NexOS Release Notes Pack:
- Adds release notes generator, included tool summaries, desktop UX changes, build/release tools list, known checks, first-run checklist, installed command/app lists, Control Panel integration, Action Center integration, dock/menu entries, and assistant catalog entries.
APPMAP
chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel; rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK
sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/530-nexos-release-notes-pack.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/530-nexos-release-notes-pack.hook.chroot"
success "Injected NexOS Release Notes Pack for $NEXOS_EDITION."
