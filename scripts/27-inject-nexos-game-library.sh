#!/usr/bin/env bash
# NexOS Game Library integration.
# Adds a real local game/ROM library manager, import wizard, favorites database,
# per-extension launch routing, reports, and AI/dock integration.
# No ROMs, BIOS files, keys, firmware dumps, or copyrighted games are included.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

NEXOS_EDITION="${NEXOS_EDITION:-main}"
EDITION_LABEL="${EDITION_LABEL:-NexOS Main}"

ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"

cat > "$LB_CONFIG_DIR/package-lists/60-nexos-game-library.list.chroot" <<'PKGS'
# NexOS Game Library support.
python3
python3-tk
xdg-utils
libnotify-bin
p7zip-full
unzip
zip
PKGS

cat > "$LB_CONFIG_DIR/hooks/normal/190-nexos-game-library.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
lib_dir="/opt/nexos/game-library"
icon_dir="/usr/share/icons/hicolor/scalable/apps"

install_if_available() {
  local pkg="$1"
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    apt-get install -y --no-install-recommends "$pkg" || true
  fi
}

apt-get update || true
for pkg in python3 python3-tk xdg-utils libnotify-bin p7zip-full unzip zip; do
  install_if_available "$pkg"
done

mkdir -p \
  "$lib_dir" \
  "$icon_dir" \
  /usr/local/bin \
  /usr/share/applications \
  /usr/share/nexos \
  "$home_dir/Games/NexOS/ROMs" \
  "$home_dir/Games/NexOS/Imported" \
  "$home_dir/Games/NexOS/Library" \
  "$home_dir/Games/NexOS/Saves" \
  "$home_dir/Games/NexOS/Screenshots" \
  "$home_dir/Games/NexOS/Configs" \
  "$home_dir/.config/nexos/game-library"

cat > "$icon_dir/nexos-game-library.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#111827"/><stop offset="1" stop-color="#020617"/></linearGradient>
    <linearGradient id="a" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#38bdf8"/><stop offset="1" stop-color="#a78bfa"/></linearGradient>
  </defs>
  <rect x="8" y="8" width="112" height="112" rx="28" fill="url(#bg)" stroke="#38bdf8" stroke-width="4"/>
  <rect x="29" y="32" width="70" height="64" rx="10" fill="none" stroke="url(#a)" stroke-width="7"/>
  <path d="M43 50h42M43 64h42M43 78h27" stroke="#e8f7ff" stroke-width="6" stroke-linecap="round"/>
  <path d="M82 76l7 7 14-17" fill="none" stroke="#22c55e" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
SVG

cat > "$lib_dir/launch_rules.json" <<'JSON'
{
  "version": 1,
  "legal_note": "NexOS does not include ROMs, BIOS files, keys, firmware dumps, or copyrighted games.",
  "rules": {
    ".nes": ["retroarch"],
    ".fds": ["retroarch"],
    ".sfc": ["retroarch"],
    ".smc": ["retroarch"],
    ".gb": ["retroarch", "mgba-qt"],
    ".gbc": ["retroarch", "mgba-qt"],
    ".gba": ["mgba-qt", "retroarch"],
    ".n64": ["mupen64plus"],
    ".z64": ["mupen64plus"],
    ".v64": ["mupen64plus"],
    ".iso": ["pcsx2", "dolphin-emu", "ppsspp"],
    ".cso": ["ppsspp"],
    ".rvz": ["dolphin-emu"],
    ".gcm": ["dolphin-emu"],
    ".wad": ["dolphin-emu"],
    ".cue": ["retroarch", "mednafen"],
    ".chd": ["retroarch", "mame"],
    ".zip": ["mame", "retroarch"],
    ".7z": ["mame", "retroarch"],
    ".md": ["retroarch"],
    ".gen": ["retroarch"],
    ".sms": ["retroarch"],
    ".gg": ["retroarch"],
    ".32x": ["retroarch"],
    ".dosbox": ["dosbox"],
    ".scummvm": ["scummvm"]
  }
}
JSON

cat > /usr/local/bin/nexos-game-import <<'PY'
#!/usr/bin/env python3
from __future__ import annotations
import shutil, sys
from pathlib import Path

ROOT = Path.home() / 'Games' / 'NexOS'
ROMS = ROOT / 'ROMs'
IMPORTED = ROOT / 'Imported'
EXT_MAP = {
    '.nes':'NES', '.fds':'NES', '.sfc':'SNES', '.smc':'SNES', '.gb':'GameBoy', '.gbc':'GameBoy', '.gba':'GameBoyAdvance',
    '.n64':'Nintendo64', '.z64':'Nintendo64', '.v64':'Nintendo64', '.iso':'DiscImages', '.cue':'DiscImages', '.bin':'DiscImages',
    '.chd':'DiscImages', '.cso':'PSP', '.pbp':'PlayStation', '.rvz':'GameCube', '.gcm':'GameCube', '.wad':'Wii',
    '.zip':'Arcade', '.7z':'Arcade', '.md':'Sega', '.gen':'Sega', '.sms':'Sega', '.gg':'Sega', '.32x':'Sega',
    '.dosbox':'DOS', '.scummvm':'ScummVM'
}
for p in (ROMS, IMPORTED):
    p.mkdir(parents=True, exist_ok=True)

if len(sys.argv) < 2:
    print('Usage: nexos-game-import <file-or-folder> [...]')
    print('Copies legal game files into ~/Games/NexOS/ROMs by type.')
    sys.exit(0)

copied = 0
for arg in sys.argv[1:]:
    src = Path(arg).expanduser()
    files = [src] if src.is_file() else [p for p in src.rglob('*') if p.is_file()] if src.is_dir() else []
    for file in files:
        folder = EXT_MAP.get(file.suffix.lower(), 'Imported')
        dest_dir = ROMS / folder if folder != 'Imported' else IMPORTED
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = dest_dir / file.name
        n = 1
        while dest.exists():
            dest = dest_dir / f'{file.stem}_{n}{file.suffix}'
            n += 1
        shutil.copy2(file, dest)
        copied += 1
        print(f'Imported: {file} -> {dest}')
print(f'Done. Imported {copied} file(s).')
PY
chmod 0755 /usr/local/bin/nexos-game-import

cat > /usr/local/bin/nexos-game-launch <<'PY'
#!/usr/bin/env python3
from __future__ import annotations
import json, shutil, subprocess, sys
from pathlib import Path

RULES = Path('/opt/nexos/game-library/launch_rules.json')

def load_rules():
    try:
        return json.loads(RULES.read_text(encoding='utf-8')).get('rules', {})
    except Exception:
        return {}

def launch(path: Path):
    if not path.exists():
        print(f'File not found: {path}')
        return 1
    rules = load_rules()
    commands = rules.get(path.suffix.lower(), [])
    for cmd in commands:
        exe = cmd.split()[0]
        if shutil.which(exe):
            subprocess.Popen(cmd.split() + [str(path)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print(f'Launching with {cmd}: {path}')
            return 0
    print(f'No installed launcher found for {path.suffix}. Open NexOS Emulator Center to install/launch emulators.')
    return 2

if len(sys.argv) < 2:
    print('Usage: nexos-game-launch <game-file>')
    sys.exit(0)
sys.exit(launch(Path(sys.argv[1]).expanduser()))
PY
chmod 0755 /usr/local/bin/nexos-game-launch

cat > /usr/local/bin/nexos-game-library <<'PY'
#!/usr/bin/env python3
from __future__ import annotations
import json, os, shutil, subprocess, tkinter as tk
from pathlib import Path
from tkinter import ttk, filedialog, messagebox

ROOT = Path.home() / 'Games' / 'NexOS'
ROMS = ROOT / 'ROMs'
BIOS = ROOT / 'BIOS'
SAVES = ROOT / 'Saves'
SHOTS = ROOT / 'Screenshots'
CONFIGS = ROOT / 'Configs'
DB_DIR = Path.home() / '.config' / 'nexos' / 'game-library'
DB = DB_DIR / 'library.json'
FAVS = DB_DIR / 'favorites.json'
REPORT = ROOT / 'game-library-report.json'
EXTS = {'.nes','.fds','.sfc','.smc','.gb','.gbc','.gba','.n64','.z64','.v64','.iso','.cue','.bin','.chd','.cso','.pbp','.rvz','.gcm','.wad','.zip','.7z','.md','.gen','.sms','.gg','.32x','.dosbox','.scummvm'}
TYPE_MAP = {
    '.nes':'NES', '.fds':'NES', '.sfc':'SNES', '.smc':'SNES', '.gb':'Game Boy', '.gbc':'Game Boy Color', '.gba':'Game Boy Advance',
    '.n64':'Nintendo 64', '.z64':'Nintendo 64', '.v64':'Nintendo 64', '.iso':'Disc image', '.cue':'Disc image', '.bin':'Binary/disc',
    '.chd':'Compressed disc', '.cso':'PSP', '.pbp':'PlayStation/PSP', '.rvz':'GameCube/Wii', '.gcm':'GameCube', '.wad':'Wii',
    '.zip':'Archive/Arcade', '.7z':'Archive/Arcade', '.md':'Sega', '.gen':'Sega', '.sms':'Sega', '.gg':'Sega', '.32x':'Sega 32X',
    '.dosbox':'DOSBox profile', '.scummvm':'ScummVM profile'
}
for p in (ROMS, BIOS, SAVES, SHOTS, CONFIGS, DB_DIR):
    p.mkdir(parents=True, exist_ok=True)

def read_json(path, default):
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except Exception:
        return default

def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2), encoding='utf-8')

def scan():
    items = []
    for file in ROMS.rglob('*'):
        if file.is_file() and file.suffix.lower() in EXTS:
            stat = file.stat()
            items.append({
                'name': file.stem,
                'file': str(file),
                'relative': str(file.relative_to(ROMS)),
                'type': TYPE_MAP.get(file.suffix.lower(), 'Unknown'),
                'ext': file.suffix.lower(),
                'size_mb': round(stat.st_size/(1024*1024), 2)
            })
    write_json(DB, {'items': items})
    write_json(REPORT, {'rom_root': str(ROMS), 'items': items})
    return items

def current_items():
    return read_json(DB, {}).get('items', []) or scan()

def favorites():
    return set(read_json(FAVS, []))

def save_favorites(favs):
    write_json(FAVS, sorted(favs))

def open_path(path: Path):
    path.mkdir(parents=True, exist_ok=True)
    subprocess.Popen(['xdg-open', str(path)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def launch_selected():
    item = get_selected()
    if not item:
        return
    subprocess.Popen(['nexos-game-launch', item['file']], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def import_files():
    files = filedialog.askopenfilenames(title='Import your own legal game files')
    if not files:
        return
    subprocess.run(['nexos-game-import'] + list(files))
    refresh()

def get_selected():
    sel = table.selection()
    if not sel:
        messagebox.showinfo('NexOS Game Library', 'Select a game first.')
        return None
    idx = int(table.item(sel[0], 'text'))
    return visible_items[idx]

def toggle_favorite():
    item = get_selected()
    if not item:
        return
    favs = favorites()
    key = item['file']
    if key in favs:
        favs.remove(key)
    else:
        favs.add(key)
    save_favorites(favs)
    refresh()

def show_report():
    scan()
    open_path(ROOT)

def refresh():
    global visible_items
    query = search_var.get().strip().lower()
    fav_only = fav_var.get()
    favs = favorites()
    items = scan()
    visible_items = []
    for item in items:
        if query and query not in item['name'].lower() and query not in item['type'].lower() and query not in item['relative'].lower():
            continue
        if fav_only and item['file'] not in favs:
            continue
        visible_items.append(item)
    for row in table.get_children():
        table.delete(row)
    for i, item in enumerate(visible_items):
        star = '★' if item['file'] in favs else ''
        table.insert('', 'end', text=str(i), values=(star, item['name'], item['type'], item['size_mb'], item['relative']))
    status.configure(text=f'{len(visible_items)} shown / {len(items)} found. No ROMs or BIOS are included with NexOS.')

root = tk.Tk()
root.title('NexOS Game Library')
root.geometry('1120x720')
root.configure(bg='#07111f')
root.minsize(940, 620)
try:
    ttk.Style(root).theme_use('clam')
except Exception:
    pass

header = tk.Frame(root, bg='#07111f', padx=22, pady=16)
header.pack(fill='x')
tk.Label(header, text='NexOS Game Library', bg='#07111f', fg='#e8f7ff', font=('Sans', 28, 'bold')).pack(side='left')
tk.Label(header, text='Local library for your own legal games only.', bg='#07111f', fg='#9bd5ff', font=('Sans', 11)).pack(side='right')

bar = tk.Frame(root, bg='#07111f', padx=18, pady=8)
bar.pack(fill='x')
search_var = tk.StringVar()
fav_var = tk.BooleanVar(value=False)
tk.Label(bar, text='Search:', bg='#07111f', fg='#e8f7ff').pack(side='left')
entry = tk.Entry(bar, textvariable=search_var, bg='#0d172b', fg='#e8f7ff', insertbackground='#e8f7ff', relief='flat', width=34)
entry.pack(side='left', padx=8)
entry.bind('<KeyRelease>', lambda _e: refresh())
tk.Checkbutton(bar, text='Favorites only', variable=fav_var, command=refresh, bg='#07111f', fg='#e8f7ff', selectcolor='#0d172b', activebackground='#07111f').pack(side='left', padx=8)
for label, cmd in [('Refresh', refresh), ('Import', import_files), ('Launch', launch_selected), ('Favorite', toggle_favorite), ('Report', show_report)]:
    tk.Button(bar, text=label, command=cmd, bg='#1f2937', fg='#e8f7ff', activebackground='#0ea5e9', relief='flat', padx=12, pady=7).pack(side='left', padx=4)

tools = tk.Frame(root, bg='#07111f', padx=18, pady=4)
tools.pack(fill='x')
for label, path in [('ROMs', ROMS), ('BIOS', BIOS), ('Saves', SAVES), ('Screenshots', SHOTS), ('Configs', CONFIGS)]:
    tk.Button(tools, text='Open '+label, command=lambda p=path: open_path(p), bg='#111827', fg='#c7d2fe', activebackground='#312e81', relief='flat', padx=10, pady=6).pack(side='left', padx=4)
for label, cmd in [('Emulator Center', 'nexos-emulator-center'), ('Gaming Center', 'nexos-gaming-center'), ('BIOS Manager', 'nexos-bios-manager')]:
    tk.Button(tools, text=label, command=lambda c=cmd: subprocess.Popen([c], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL), bg='#14532d', fg='#e8f7ff', activebackground='#16a34a', relief='flat', padx=10, pady=6).pack(side='right', padx=4)

cols = ('Fav', 'Title', 'System/Type', 'Size MB', 'File')
table = ttk.Treeview(root, columns=cols, show='headings')
for col in cols:
    table.heading(col, text=col)
    table.column(col, width=70 if col == 'Fav' else 220 if col != 'File' else 420)
table.pack(fill='both', expand=True, padx=18, pady=12)
table.bind('<Double-1>', lambda _e: launch_selected())

status = tk.Label(root, text='', bg='#07111f', fg='#9bd5ff', anchor='w')
status.pack(fill='x', padx=18, pady=(0, 14))
visible_items = []
refresh()
root.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-game-library

cat > /usr/share/applications/nexos-game-library.desktop <<'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=NexOS Game Library
Comment=Scan, import, favorite, and launch your own legal game files
Exec=nexos-game-library
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-game-library.svg
Terminal=false
StartupNotify=false
Categories=Game;Emulator;
X-XFCE-Trusted=true
DESKTOP
chmod 0755 /usr/share/applications/nexos-game-library.desktop

cat > /usr/share/applications/nexos-game-import.desktop <<'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=NexOS Game Import
Comment=Import legal game files into NexOS folders
Exec=nexos-game-library
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-game-library.svg
Terminal=false
StartupNotify=false
Categories=Game;Emulator;
X-XFCE-Trusted=true
DESKTOP
chmod 0755 /usr/share/applications/nexos-game-import.desktop

# Add Game Library to the dock if available.
if [[ -f /usr/local/bin/nexos-dock ]]; then
  python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock')
s=p.read_text()
if 'nexos-game-library' not in s:
    old='''    ("Gaming", ["nexos-gaming-center"]),\n]'''
    new='''    ("Gaming", ["nexos-gaming-center"]),\n    ("Library", ["nexos-game-library"]),\n]'''
    if old in s:
        s=s.replace(old,new)
    else:
        insert='    ("Library", ["nexos-game-library"]),\n'
        s=s.replace('\n]', '\n'+insert+']', 1)
    p.write_text(s)
PY
  chmod 0755 /usr/local/bin/nexos-dock
fi

# Add Game Library to Gaming Center quick launch if present.
if [[ -f /usr/local/bin/nexos-gaming-center ]]; then
  python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-gaming-center')
s=p.read_text()
if "('Game Library'" not in s:
    old="""buttons = [\n    ('Emulator Center', lambda: run('nexos-emulator-center')),"""
    new="""buttons = [\n    ('Game Library', lambda: run('nexos-game-library')),\n    ('Emulator Center', lambda: run('nexos-emulator-center')),"""
    if old in s:
        p.write_text(s.replace(old,new))
PY
  chmod 0755 /usr/local/bin/nexos-gaming-center
fi

# Add assistant catalog entries and skill if the assistant exists.
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then
  python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json')
data=json.loads(p.read_text())
for key,cmd,label in [
    ('game library','nexos-game-library','NexOS Game Library'),
    ('library','nexos-game-library','NexOS Game Library'),
    ('game import','nexos-game-library','NexOS Game Import')
]:
    data[key]={'label':label,'commands':[cmd],'permission':'app.open'}
p.write_text(json.dumps(data, indent=2))
PY
fi

if [[ -d /opt/nexos/NexOS_AI_Assistant/skills ]]; then
  cat > /opt/nexos/NexOS_AI_Assistant/skills/game-library.skill.json <<'JSON'
{
  "id": "game-library",
  "name": "Game Library",
  "description": "Opens NexOS Game Library to scan, import, favorite, and launch legal local game files.",
  "intents": ["app.open"],
  "examples": ["Hey NexOS open game library", "Hey NexOS open library"]
}
JSON
fi

cat > /usr/share/nexos/NEXOS_GAME_LIBRARY.md <<'MD'
# NexOS Game Library

NexOS Game Library is a local library manager for your own legal game files.

It can:

- Scan `~/Games/NexOS/ROMs`
- Import legal game files into organized folders
- Favorite games
- Write a JSON library report
- Launch games through installed open-source emulators when available
- Open Emulator Center, Gaming Center, and BIOS Manager
- Work with NexOS Assistant commands

Commands:

```bash
nexos-game-library
nexos-game-import ~/Downloads/MyLegalGameFile.ext
nexos-game-launch ~/Games/NexOS/ROMs/NES/example.nes
```

Assistant examples:

```bash
nexos-command-router "hey nexos open game library" --json
nexos-command-router "hey nexos open library" --json
```

NexOS does not include ROMs, BIOS files, keys, firmware dumps, or copyrighted games.
MD

cat >> /usr/share/nexos/app-map.txt <<'APPMAP_APPEND'

NexOS Game Library:
- Adds local library GUI for legal game files.
- Adds importer, scanner, favorites, and launcher routing.
- Adds dock entry, Gaming Center quick launch, app launchers, docs, and assistant skill/catalog entries.
- Does not include ROMs, BIOS files, keys, firmware dumps, or copyrighted games.
APPMAP_APPEND

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi

chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel
rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK

sed -i \
  -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" \
  "$LB_CONFIG_DIR/hooks/normal/190-nexos-game-library.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/190-nexos-game-library.hook.chroot"

success "Injected NexOS Game Library for $NEXOS_EDITION."
