#!/usr/bin/env bash
# NexOS AI Assistant v2 integration pass.
# Adds a safer skill runtime, OS action helpers, service files, settings/history tools,
# notification support, and stronger desktop/startup integration.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

NEXOS_EDITION="${NEXOS_EDITION:-main}"
EDITION_LABEL="${EDITION_LABEL:-NexOS Main}"

ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"

cat > "$LB_CONFIG_DIR/package-lists/55-nexos-ai-assistant-v2.list.chroot" <<'PKGS'
# NexOS AI Assistant v2 support.
python3
python3-tk
python3-venv
espeak-ng
libnotify-bin
xdg-utils
wmctrl
procps
pciutils
usbutils
PKGS

cat > "$LB_CONFIG_DIR/hooks/normal/145-nexos-ai-assistant-v2.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

LIVE_USERNAME="__LIVE_USERNAME__"
EDITION_LABEL="__EDITION_LABEL__"
home_dir="/home/$LIVE_USERNAME"
app_dir="/opt/nexos/NexOS_AI_Assistant"
service_dir="/etc/xdg/systemd/user"

install_if_available() {
  local pkg="$1"
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    apt-get install -y --no-install-recommends "$pkg" || true
  fi
}

apt-get update || true
for pkg in python3 python3-tk python3-venv espeak-ng libnotify-bin xdg-utils wmctrl procps pciutils usbutils; do
  install_if_available "$pkg"
done

mkdir -p \
  "$app_dir/services/skill-runtime" \
  "$app_dir/services/os-actions" \
  "$app_dir/services/native-wake-daemon" \
  "$app_dir/skills" \
  "$app_dir/integration" \
  "$app_dir/docs" \
  "$app_dir/scripts" \
  "$service_dir" \
  /usr/local/bin \
  /usr/share/applications \
  /usr/share/icons/hicolor/scalable/apps \
  "$home_dir/Desktop" \
  "$home_dir/.config/autostart"

cat > "$app_dir/integration/app_catalog.json" <<'JSON'
{
  "terminal": {"label": "Terminal", "commands": ["xfce4-terminal", "x-terminal-emulator"], "permission": "app.open"},
  "files": {"label": "Files", "commands": ["thunar", "xdg-open ."], "permission": "app.open"},
  "browser": {"label": "Browser", "commands": ["nexos-browser", "firefox-esr", "xdg-open https://www.google.com"], "permission": "app.open"},
  "settings": {"label": "Settings", "commands": ["xfce4-settings-manager"], "permission": "settings.open"},
  "control center": {"label": "NexOS Control Center", "commands": ["nexos-control-center"], "permission": "app.open"},
  "dev center": {"label": "NexOS Dev Center", "commands": ["nexos-dev-center"], "permission": "app.open"},
  "install center": {"label": "NexOS Install Center", "commands": ["nexos-install-center"], "permission": "app.open"},
  "display help": {"label": "NexOS VM Display Help", "commands": ["nexos-vm-display-help"], "permission": "app.open"},
  "gpu info": {"label": "NexOS GPU Info", "commands": ["nexos-gpu-info"], "permission": "system.status"},
  "calculator": {"label": "Calculator", "commands": ["galculator", "qalculate-gtk", "gnome-calculator"], "permission": "app.open"}
}
JSON

cat > "$app_dir/integration/permissions.json" <<'JSON'
{
  "version": 2,
  "mode": "safe",
  "allowed_intents": [
    "assistant.chat",
    "assistant.wake",
    "assistant.settings",
    "assistant.history",
    "assistant.skills",
    "dashboard.open",
    "dashboard.hide",
    "dashboard.toggle",
    "system.status",
    "system.hardware",
    "system.network",
    "app.open",
    "settings.open",
    "task.add",
    "task.list",
    "notification.send",
    "web.search",
    "files.open_home",
    "files.open_downloads"
  ],
  "dangerous_patterns": [
    "rm -rf",
    "mkfs",
    "dd if=",
    "shutdown",
    "reboot",
    "poweroff",
    "sudo ",
    "chmod -R 777 /",
    ":(){"
  ],
  "require_confirmation": [
    "files.delete",
    "settings.change",
    "package.install",
    "system.power"
  ],
  "notes": "NexOS Assistant only runs whitelisted local actions. Destructive commands are blocked by default."
}
JSON

cat > "$app_dir/services/os-actions/nexos_os_actions.py" <<'PY'
#!/usr/bin/env python3
from __future__ import annotations
import json, os, platform, shutil, subprocess, urllib.parse
from pathlib import Path

APP_DIR = Path('/opt/nexos/NexOS_AI_Assistant')
APP_CATALOG = APP_DIR / 'integration' / 'app_catalog.json'
PERMISSIONS = APP_DIR / 'integration' / 'permissions.json'
USER_DIR = Path.home() / '.nexos-assistant'
TASKS_PATH = USER_DIR / 'tasks.json'

def load_json(path: Path, default):
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except Exception:
        return default

def save_json(path: Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2), encoding='utf-8')

def blocked(text: str) -> bool:
    perms = load_json(PERMISSIONS, {})
    low = text.lower()
    return any(p.lower() in low for p in perms.get('dangerous_patterns', []))

def notify(title: str, body: str) -> bool:
    if shutil.which('notify-send'):
        subprocess.Popen(['notify-send', title, body], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    return False

def speak(text: str) -> bool:
    if shutil.which('espeak-ng'):
        subprocess.Popen(['espeak-ng', text], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    return False

def run_first(commands: list[str]):
    for raw in commands:
        exe = raw.split()[0]
        if shutil.which(exe):
            subprocess.Popen(raw.split(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True, f'Opened {exe}.'
    return False, 'No installed command matched this action.'

def open_app(target: str):
    if blocked(target):
        return False, 'Blocked unsafe command text.'
    catalog = load_json(APP_CATALOG, {})
    key = target.strip().lower().replace('nexos ', '')
    item = catalog.get(key)
    if not item:
        # fuzzy contains matching, but still only catalog items
        for name, value in catalog.items():
            if key in name or name in key:
                item = value
                break
    if not item:
        return False, f'{target} is not in the safe NexOS app catalog.'
    ok, msg = run_first(item.get('commands', []))
    return ok, msg if ok else f'{item.get("label", target)} is allowed, but none of its launchers are installed.'

def system_status() -> str:
    disk = shutil.disk_usage(str(Path.home()))
    mem_line = ''
    try:
        meminfo = Path('/proc/meminfo').read_text().splitlines()
        total = next((x for x in meminfo if x.startswith('MemTotal:')), '')
        avail = next((x for x in meminfo if x.startswith('MemAvailable:')), '')
        mem_line = f'{total} | {avail}'
    except Exception:
        pass
    return '\n'.join([
        f'OS: NexOS on {platform.system()} {platform.release()}',
        f'CPU cores: {os.cpu_count()}',
        f'Memory: {mem_line}',
        f'Disk home: {disk.used // (1024**3)}GB used / {disk.total // (1024**3)}GB total',
        'Assistant API: http://127.0.0.1:4780'
    ])

def hardware_summary() -> str:
    out = []
    for cmd in (['lspci'], ['lsusb']):
        if shutil.which(cmd[0]):
            try:
                out.append('$ ' + ' '.join(cmd))
                out.append(subprocess.check_output(cmd, text=True, stderr=subprocess.STDOUT, timeout=4)[:2500])
            except Exception as exc:
                out.append(str(exc))
    return '\n'.join(out) or 'Hardware tools are not installed.'

def open_home():
    return run_first(['thunar ' + str(Path.home()), 'xdg-open ' + str(Path.home())])

def open_downloads():
    downloads = Path.home() / 'Downloads'
    downloads.mkdir(exist_ok=True)
    return run_first(['thunar ' + str(downloads), 'xdg-open ' + str(downloads)])

def add_task(text: str):
    tasks = load_json(TASKS_PATH, [])
    tasks.append({'text': text, 'done': False})
    save_json(TASKS_PATH, tasks)
    return True, 'Task added.'

def list_tasks() -> str:
    tasks = load_json(TASKS_PATH, [])
    if not tasks:
        return 'No tasks yet.'
    return '\n'.join([f"{'✓' if t.get('done') else '•'} {t.get('text','')}" for t in tasks])

def web_search(query: str):
    q = urllib.parse.quote_plus(query)
    return run_first([f'nexos-browser https://www.google.com/search?q={q}', f'xdg-open https://www.google.com/search?q={q}'])
PY
chmod 0755 "$app_dir/services/os-actions/nexos_os_actions.py"

cat > "$app_dir/services/skill-runtime/nexos_skill_runtime.py" <<'PY'
#!/usr/bin/env python3
from __future__ import annotations
import json, re, sys
from pathlib import Path
sys.path.insert(0, '/opt/nexos/NexOS_AI_Assistant/services/os-actions')
import nexos_os_actions as osact

APP_DIR = Path('/opt/nexos/NexOS_AI_Assistant')
SKILLS_DIR = APP_DIR / 'skills'
WAKE = ('hey nexos', 'hey nexus', 'ok nexos', 'okay nexos')

def strip_wake(text: str) -> str:
    low = text.strip().lower()
    for w in WAKE:
        if low.startswith(w):
            return text.strip()[len(w):].strip(' ,')
    return text.strip()

def route(text: str) -> dict:
    raw = text.strip()
    cmd = strip_wake(raw).strip()
    low = cmd.lower()
    if not cmd:
        return {'ok': True, 'intent': 'assistant.wake', 'message': 'I am listening.'}
    if low in ('open dashboard','show dashboard','open assistant'):
        return {'ok': True, 'intent': 'dashboard.open', 'message': 'Opening dashboard.'}
    if low in ('hide dashboard','close dashboard'):
        return {'ok': True, 'intent': 'dashboard.hide', 'message': 'Closing dashboard.'}
    if low in ('toggle dashboard','toggle assistant'):
        return {'ok': True, 'intent': 'dashboard.toggle', 'message': 'Toggling dashboard.'}
    if low in ('system status','status','how is the system'):
        return {'ok': True, 'intent': 'system.status', 'message': osact.system_status()}
    if low in ('hardware status','hardware info','show hardware'):
        return {'ok': True, 'intent': 'system.hardware', 'message': osact.hardware_summary()}
    if low in ('open home','open home folder'):
        ok,msg=osact.open_home(); return {'ok': ok, 'intent': 'files.open_home', 'message': msg}
    if low in ('open downloads','open downloads folder'):
        ok,msg=osact.open_downloads(); return {'ok': ok, 'intent': 'files.open_downloads', 'message': msg}
    if low.startswith('open '):
        target = low[5:].strip()
        ok,msg=osact.open_app(target); return {'ok': ok, 'intent': 'app.open', 'target': target, 'message': msg}
    if low.startswith('add task '):
        ok,msg=osact.add_task(cmd[9:].strip()); return {'ok': ok, 'intent': 'task.add', 'message': msg}
    if low in ('list tasks','show tasks'):
        return {'ok': True, 'intent': 'task.list', 'message': osact.list_tasks()}
    if low.startswith('search web '):
        q=cmd[11:].strip(); ok,msg=osact.web_search(q); return {'ok': ok, 'intent': 'web.search', 'target': q, 'message': msg}
    if low.startswith('notify '):
        body=cmd[7:].strip(); ok=osact.notify('NexOS', body); return {'ok': ok, 'intent': 'notification.send', 'message': body}
    return {'ok': True, 'intent': 'assistant.chat', 'message': 'Local command understood. Connect a local or cloud LLM provider in settings for full AI chat.'}

def list_skills():
    return [json.loads(p.read_text(encoding='utf-8')) for p in SKILLS_DIR.glob('*.skill.json')]

if __name__ == '__main__':
    text = ' '.join(sys.argv[1:]) or sys.stdin.read()
    print(json.dumps(route(text), indent=2))
PY
chmod 0755 "$app_dir/services/skill-runtime/nexos_skill_runtime.py"

cat > "$app_dir/skills/file-manager.skill.json" <<'JSON'
{
  "id": "file-manager",
  "name": "File Manager",
  "description": "Safely opens Home and Downloads folders.",
  "intents": ["files.open_home", "files.open_downloads"],
  "examples": ["Hey NexOS open home", "Hey NexOS open downloads"]
}
JSON
cat > "$app_dir/skills/notifications.skill.json" <<'JSON'
{
  "id": "notifications",
  "name": "Notifications",
  "description": "Sends local NexOS desktop notifications.",
  "intents": ["notification.send"],
  "examples": ["Hey NexOS notify test completed"]
}
JSON
cat > "$app_dir/skills/hardware.skill.json" <<'JSON'
{
  "id": "hardware",
  "name": "Hardware Info",
  "description": "Shows safe local hardware summaries.",
  "intents": ["system.hardware", "system.status"],
  "examples": ["Hey NexOS hardware info", "Hey NexOS system status"]
}
JSON

cat > /usr/local/bin/nexos-skill-runtime <<EOF
#!/usr/bin/env bash
exec python3 "$app_dir/services/skill-runtime/nexos_skill_runtime.py" "\$@"
EOF
chmod 0755 /usr/local/bin/nexos-skill-runtime

cat > /usr/local/bin/nexos-ai-settings <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
settings="$HOME/.nexos-assistant/settings.json"
mkdir -p "$(dirname "$settings")"
if [[ ! -f "$settings" ]]; then
  cat > "$settings" <<'JSON'
{
  "voice": true,
  "wake": true,
  "startup_orb": true,
  "api_port": 4780,
  "llm_provider": "none",
  "notes": "Set llm_provider later to local, openai, anthropic, ollama, etc."
}
JSON
fi
if command -v mousepad >/dev/null 2>&1; then
  mousepad "$settings" >/dev/null 2>&1 &
else
  xdg-open "$settings" >/dev/null 2>&1 &
fi
EOF
chmod 0755 /usr/local/bin/nexos-ai-settings

cat > /usr/local/bin/nexos-ai-history <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
history="$HOME/.nexos-assistant/command_history.jsonl"
mkdir -p "$(dirname "$history")"
touch "$history"
if command -v mousepad >/dev/null 2>&1; then
  mousepad "$history" >/dev/null 2>&1 &
else
  xdg-open "$history" >/dev/null 2>&1 &
fi
EOF
chmod 0755 /usr/local/bin/nexos-ai-history

cat > /usr/local/bin/nexos-ai-skills <<EOF
#!/usr/bin/env bash
set -euo pipefail
if command -v mousepad >/dev/null 2>&1; then
  mousepad "$app_dir"/skills/*.skill.json >/dev/null 2>&1 &
else
  xdg-open "$app_dir/skills" >/dev/null 2>&1 &
fi
EOF
chmod 0755 /usr/local/bin/nexos-ai-skills

cat > /usr/share/applications/nexos-ai-settings.desktop <<'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=NexOS AI Settings
Comment=Edit NexOS Assistant runtime settings
Exec=nexos-ai-settings
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-ai-assistant.svg
Terminal=false
StartupNotify=false
Categories=Settings;System;
X-XFCE-Trusted=true
DESKTOP
chmod 0755 /usr/share/applications/nexos-ai-settings.desktop

cat > /usr/share/applications/nexos-ai-history.desktop <<'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=NexOS AI History
Comment=Open NexOS Assistant command history
Exec=nexos-ai-history
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-ai-assistant.svg
Terminal=false
StartupNotify=false
Categories=Utility;System;
X-XFCE-Trusted=true
DESKTOP
chmod 0755 /usr/share/applications/nexos-ai-history.desktop

cat > /usr/share/applications/nexos-ai-skills.desktop <<'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=NexOS AI Skills
Comment=Open NexOS Assistant skills folder
Exec=nexos-ai-skills
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-ai-assistant.svg
Terminal=false
StartupNotify=false
Categories=Utility;System;
X-XFCE-Trusted=true
DESKTOP
chmod 0755 /usr/share/applications/nexos-ai-skills.desktop

cat > "$service_dir/nexos-assistant.service" <<'SERVICE'
[Unit]
Description=NexOS AI Assistant orb, dashboard, and local API
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/local/bin/nexos-assistant
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
SERVICE

cat > "$home_dir/.config/autostart/nexos-assistant.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Assistant
Comment=Start NexOS AI assistant orb and local API
Exec=sh -c 'sleep 5; nexos-assistant'
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-ai-assistant.svg
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP

cat > "$app_dir/docs/NEXOS_AI_ASSISTANT_V2.md" <<'MD'
# NexOS AI Assistant v2

New commands:

```bash
nexos-ai-settings
nexos-ai-history
nexos-ai-skills
nexos-skill-runtime "hey nexos system status"
nexos-skill-runtime "hey nexos open downloads"
nexos-skill-runtime "hey nexos notify ISO build done"
```

New runtime files:

- `/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json`
- `/opt/nexos/NexOS_AI_Assistant/integration/permissions.json`
- `/opt/nexos/NexOS_AI_Assistant/services/skill-runtime/nexos_skill_runtime.py`
- `/opt/nexos/NexOS_AI_Assistant/services/os-actions/nexos_os_actions.py`
- `/etc/xdg/systemd/user/nexos-assistant.service`

The assistant still uses safe whitelisted OS actions. It does not run arbitrary shell commands.
MD

cat >> /usr/share/nexos/app-map.txt <<'APPMAP_APPEND'

NexOS AI Assistant v2:
- Adds app_catalog.json for safe app launching.
- Adds skill-runtime and os-actions Python services.
- Adds AI Settings, AI History, and AI Skills launchers.
- Adds local notifications, file folder actions, hardware summaries, task listing, and web search routing.
- Adds a user-level systemd service file for later installed sessions.
APPMAP_APPEND

# Put AI tools on desktop for this build pass.
for src in nexos-ai-settings.desktop nexos-ai-history.desktop nexos-ai-skills.desktop; do
  cp -f "/usr/share/applications/$src" "$home_dir/Desktop/${src%.desktop}.desktop" || true
  chmod 0755 "$home_dir/Desktop/${src%.desktop}.desktop" 2>/dev/null || true
  if command -v gio >/dev/null 2>&1; then
    gio set "$home_dir/Desktop/${src%.desktop}.desktop" metadata::trusted true 2>/dev/null || true
  fi
done

chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel
rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK

sed -i \
  -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" \
  -e "s/__EDITION_LABEL__/$EDITION_LABEL/g" \
  "$LB_CONFIG_DIR/hooks/normal/145-nexos-ai-assistant-v2.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/145-nexos-ai-assistant-v2.hook.chroot"

success "Injected NexOS AI Assistant v2 for $NEXOS_EDITION."
