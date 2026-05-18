#!/usr/bin/env bash
# NexOS Console Mode integration.
# Adds a fullscreen TV/console-style launcher for legal local game files and NexOS gaming tools.
# No game files, BIOS files, firmware dumps, keys, or copyrighted content are included.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

NEXOS_EDITION="${NEXOS_EDITION:-main}"

ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"

cat > "$LB_CONFIG_DIR/package-lists/61-nexos-console-mode.list.chroot" <<'PKGS'
# NexOS Console Mode support.
python3
python3-tk
xdg-utils
libnotify-bin
wmctrl
PKGS

cat > "$LB_CONFIG_DIR/hooks/normal/200-nexos-console-mode.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
console_dir="/opt/nexos/console-mode"
icon_dir="/usr/share/icons/hicolor/scalable/apps"

install_if_available() {
  local pkg="$1"
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    apt-get install -y --no-install-recommends "$pkg" || true
  fi
}

apt-get update || true
for pkg in python3 python3-tk xdg-utils libnotify-bin wmctrl; do
  install_if_available "$pkg"
done

mkdir -p "$console_dir" "$icon_dir" /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/.config/nexos/console-mode" "$home_dir/Games/NexOS/ROMs"

cat > "$icon_dir/nexos-console-mode.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#111827"/><stop offset="1" stop-color="#020617"/></linearGradient>
    <linearGradient id="a" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#22c55e"/><stop offset="1" stop-color="#38bdf8"/></linearGradient>
  </defs>
  <rect x="8" y="8" width="112" height="112" rx="28" fill="url(#bg)" stroke="#22c55e" stroke-width="4"/>
  <rect x="25" y="36" width="78" height="49" rx="9" fill="none" stroke="url(#a)" stroke-width="7"/>
  <path d="M42 101h44M64 85v16" stroke="#e8f7ff" stroke-width="7" stroke-linecap="round"/>
  <circle cx="49" cy="60" r="6" fill="#e8f7ff"/>
  <path d="M72 58h18M81 49v18" stroke="#e8f7ff" stroke-width="5" stroke-linecap="round"/>
</svg>
SVG

cat > "$console_dir/console_mode_settings.json" <<'JSON'
{
  "version": 1,
  "start_fullscreen": true,
  "rom_root": "~/Games/NexOS/ROMs",
  "show_tools": true,
  "legal_note": "NexOS Console Mode launches only local files you provide. NexOS includes no games, BIOS files, keys, or copyrighted content."
}
JSON

cat > /usr/local/bin/nexos-console-mode <<'PY'
#!/usr/bin/env python3
from __future__ import annotations
import json, shutil, subprocess, tkinter as tk
from pathlib import Path
from tkinter import messagebox

ROOT = Path.home() / 'Games' / 'NexOS'
ROMS = ROOT / 'ROMs'
ROMS.mkdir(parents=True, exist_ok=True)
EXTS = {'.nes','.fds','.sfc','.smc','.gb','.gbc','.gba','.n64','.z64','.v64','.iso','.cue','.bin','.chd','.cso','.pbp','.rvz','.gcm','.wad','.zip','.7z','.md','.gen','.sms','.gg','.32x','.dosbox','.scummvm'}
TOOLS = [
    ('Game Library', 'nexos-game-library'),
    ('Gaming Center', 'nexos-gaming-center'),
    ('Emulator Center', 'nexos-emulator-center'),
    ('BIOS Manager', 'nexos-bios-manager'),
    ('Scan Games', 'x-terminal-emulator -e nexos-game-scan'),
    ('Gaming Health', 'x-terminal-emulator -e nexos-game-health'),
    ('Files', 'thunar ' + str(ROMS)),
]

def run_cmd(raw: str):
    exe = raw.split()[0]
    if shutil.which(exe):
        subprocess.Popen(raw.split(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        messagebox.showwarning('NexOS Console Mode', f'{exe} is not installed or unavailable in this build.')

def launch_game(path: Path):
    if shutil.which('nexos-game-launch'):
        subprocess.Popen(['nexos-game-launch', str(path)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        messagebox.showwarning('NexOS Console Mode', 'nexos-game-launch is not installed yet.')

def scan_games():
    games = []
    for file in ROMS.rglob('*'):
        if file.is_file() and file.suffix.lower() in EXTS:
            games.append(file)
    return sorted(games, key=lambda p: p.name.lower())

root = tk.Tk()
root.title('NexOS Console Mode')
root.configure(bg='#020617')
root.geometry('1180x720')
try:
    root.attributes('-fullscreen', True)
except Exception:
    pass
root.bind('<Escape>', lambda _e: root.destroy())
root.bind('<F11>', lambda _e: root.attributes('-fullscreen', not bool(root.attributes('-fullscreen'))))

header = tk.Frame(root, bg='#020617', padx=34, pady=24)
header.pack(fill='x')
tk.Label(header, text='NexOS Console Mode', bg='#020617', fg='#e8f7ff', font=('Sans', 38, 'bold')).pack(side='left')
tk.Label(header, text='ESC exits • F11 toggles fullscreen', bg='#020617', fg='#7dd3fc', font=('Sans', 13)).pack(side='right')

main = tk.Frame(root, bg='#020617', padx=28, pady=10)
main.pack(fill='both', expand=True)
left = tk.Frame(main, bg='#0d172b', padx=14, pady=14, highlightbackground='#294866', highlightthickness=1)
left.pack(side='left', fill='y', padx=(0, 16))
right = tk.Frame(main, bg='#020617')
right.pack(side='left', fill='both', expand=True)

tk.Label(left, text='Tools', bg='#0d172b', fg='#e8f7ff', font=('Sans', 18, 'bold')).pack(anchor='w', pady=(0, 10))
for label, cmd in TOOLS:
    tk.Button(left, text=label, command=lambda c=cmd: run_cmd(c), bg='#1f2937', fg='#e8f7ff', activebackground='#0ea5e9', relief='flat', padx=18, pady=13, width=22, font=('Sans', 12, 'bold')).pack(fill='x', pady=5)

tk.Label(left, text='Legal note:\nAdd only your own legal game files under ~/Games/NexOS/ROMs.', bg='#0d172b', fg='#a7bdd8', justify='left', wraplength=230).pack(anchor='w', pady=(24,0))

canvas = tk.Canvas(right, bg='#020617', highlightthickness=0)
scroll = tk.Scrollbar(right, orient='vertical', command=canvas.yview)
grid = tk.Frame(canvas, bg='#020617')
grid.bind('<Configure>', lambda _e: canvas.configure(scrollregion=canvas.bbox('all')))
canvas.create_window((0,0), window=grid, anchor='nw')
canvas.configure(yscrollcommand=scroll.set)
canvas.pack(side='left', fill='both', expand=True)
scroll.pack(side='right', fill='y')

games = scan_games()
if not games:
    box = tk.Frame(grid, bg='#0d172b', padx=24, pady=24, highlightbackground='#294866', highlightthickness=1)
    box.grid(row=0, column=0, sticky='ew', padx=10, pady=10)
    tk.Label(box, text='No games found', bg='#0d172b', fg='#e8f7ff', font=('Sans', 22, 'bold')).pack(anchor='w')
    tk.Label(box, text=f'Put your own legal files in:\n{ROMS}', bg='#0d172b', fg='#a7bdd8', font=('Sans', 13), justify='left').pack(anchor='w', pady=(8,0))
else:
    for i, path in enumerate(games):
        card = tk.Frame(grid, bg='#0d172b', padx=16, pady=14, highlightbackground='#294866', highlightthickness=1)
        card.grid(row=i//3, column=i%3, sticky='nsew', padx=8, pady=8)
        grid.grid_columnconfigure(i%3, weight=1)
        tk.Label(card, text=path.stem[:34], bg='#0d172b', fg='#e8f7ff', font=('Sans', 14, 'bold'), wraplength=250).pack(anchor='w')
        tk.Label(card, text=str(path.relative_to(ROMS))[:46], bg='#0d172b', fg='#a7bdd8', font=('Sans', 10), wraplength=250).pack(anchor='w', pady=(4,8))
        tk.Button(card, text='Launch', command=lambda p=path: launch_game(p), bg='#16a34a', fg='white', relief='flat', padx=18, pady=8).pack(anchor='e')

root.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-console-mode

cat > /usr/local/bin/nexos-console-settings <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
settings="$HOME/.config/nexos/console-mode/settings.json"
mkdir -p "$(dirname "$settings")"
if [[ ! -f "$settings" ]]; then
  cp /opt/nexos/console-mode/console_mode_settings.json "$settings"
fi
if command -v mousepad >/dev/null 2>&1; then
  mousepad "$settings" >/dev/null 2>&1 &
else
  xdg-open "$settings" >/dev/null 2>&1 &
fi
BASH
chmod 0755 /usr/local/bin/nexos-console-settings

cat > /usr/share/applications/nexos-console-mode.desktop <<'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=NexOS Console Mode
Comment=Fullscreen NexOS gaming console launcher
Exec=nexos-console-mode
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-console-mode.svg
Terminal=false
StartupNotify=false
Categories=Game;Emulator;
X-XFCE-Trusted=true
DESKTOP
chmod 0755 /usr/share/applications/nexos-console-mode.desktop

cat > /usr/share/applications/nexos-console-settings.desktop <<'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=NexOS Console Settings
Comment=Edit NexOS Console Mode settings
Exec=nexos-console-settings
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-console-mode.svg
Terminal=false
StartupNotify=false
Categories=Game;Settings;
X-XFCE-Trusted=true
DESKTOP
chmod 0755 /usr/share/applications/nexos-console-settings.desktop

if [[ -f /usr/local/bin/nexos-dock ]]; then
  python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock')
s=p.read_text()
if 'nexos-console-mode' not in s:
    insert='    ("Console", ["nexos-console-mode"]),\n'
    s=s.replace('\n]', '\n'+insert+']', 1)
    p.write_text(s)
PY
  chmod 0755 /usr/local/bin/nexos-dock
fi

if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then
  python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json')
data=json.loads(p.read_text())
data['console mode']={'label':'NexOS Console Mode','commands':['nexos-console-mode'],'permission':'app.open'}
data['console settings']={'label':'NexOS Console Settings','commands':['nexos-console-settings'],'permission':'app.open'}
p.write_text(json.dumps(data, indent=2))
PY
fi

if [[ -d /opt/nexos/NexOS_AI_Assistant/skills ]]; then
  cat > /opt/nexos/NexOS_AI_Assistant/skills/console-mode.skill.json <<'JSON'
{
  "id": "console-mode",
  "name": "Console Mode",
  "description": "Opens the fullscreen NexOS Console Mode launcher.",
  "intents": ["app.open"],
  "examples": ["Hey NexOS open console mode", "Hey NexOS open console settings"]
}
JSON
fi

cat > /usr/share/nexos/NEXOS_CONSOLE_MODE.md <<'MD'
# NexOS Console Mode

NexOS Console Mode is a fullscreen TV-style launcher for your own legal local game files.

Commands:

```bash
nexos-console-mode
nexos-console-settings
```

Keyboard:

- `ESC` exits
- `F11` toggles fullscreen

Assistant examples:

```bash
nexos-command-router "hey nexos open console mode" --json
nexos-command-router "hey nexos open console settings" --json
```

NexOS includes no games, BIOS files, keys, firmware dumps, or copyrighted content.
MD

cat >> /usr/share/nexos/app-map.txt <<'APPMAP_APPEND'

NexOS Console Mode:
- Fullscreen TV-style launcher for legal local game files.
- Launches files through NexOS Game Library routing.
- Adds dock entry, app launchers, settings editor, docs, and assistant skill/catalog entries.
APPMAP_APPEND

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi

chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel
rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK

sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/200-nexos-console-mode.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/200-nexos-console-mode.hook.chroot"

success "Injected NexOS Console Mode for $NEXOS_EDITION."
