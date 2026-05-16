#!/usr/bin/env bash
# NexOS Emulator Center integration.
# Adds legal emulator tooling only: launchers, folders, controller helpers, ROM directory setup,
# RetroArch/Dolphin/PCSX2/PPSSPP/MAME/DOSBox/Mednafen/ScummVM package attempts, and docs.
# No ROMs, BIOS files, keys, firmware dumps, or copyrighted game files are included.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

NEXOS_EDITION="${NEXOS_EDITION:-main}"
EDITION_LABEL="${EDITION_LABEL:-NexOS Main}"

ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"

cat > "$LB_CONFIG_DIR/package-lists/57-nexos-emulator-center.list.chroot" <<'PKGS'
# Base tools used by NexOS Emulator Center.
python3
python3-tk
xdg-utils
libnotify-bin
joystick
jstest-gtk
evtest
usbutils
pciutils
p7zip-full
unzip
zip
PKGS

cat > "$LB_CONFIG_DIR/hooks/normal/160-nexos-emulator-center.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

LIVE_USERNAME="__LIVE_USERNAME__"
EDITION_LABEL="__EDITION_LABEL__"
home_dir="/home/$LIVE_USERNAME"
emu_dir="/opt/nexos/emulator-center"
icon_dir="/usr/share/icons/hicolor/scalable/apps"

install_if_available() {
  local pkg="$1"
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    apt-get install -y --no-install-recommends "$pkg" || true
  fi
}

apt-get update || true

# Small base dependencies.
for pkg in python3 python3-tk xdg-utils libnotify-bin joystick jstest-gtk evtest usbutils pciutils p7zip-full unzip zip; do
  install_if_available "$pkg"
done

# Emulators/packages available in Debian repos vary by release/component.
# These are attempted safely and skipped if unavailable.
for pkg in \
  retroarch \
  libretro-core-info \
  libretro-bsnes-mercury-balanced \
  libretro-desmume \
  libretro-mgba \
  libretro-nestopia \
  libretro-snes9x \
  dolphin-emu \
  pcsx2 \
  ppsspp \
  mame \
  dosbox \
  mednafen \
  scummvm \
  fs-uae \
  hatari \
  mupen64plus-ui-console \
  mgba-qt; do
  install_if_available "$pkg"
done

mkdir -p \
  "$emu_dir" \
  "$icon_dir" \
  /usr/local/bin \
  /usr/share/applications \
  /usr/share/nexos \
  "$home_dir/Games/NexOS/ROMs" \
  "$home_dir/Games/NexOS/BIOS" \
  "$home_dir/Games/NexOS/Saves" \
  "$home_dir/Games/NexOS/Screenshots" \
  "$home_dir/Games/NexOS/Configs" \
  "$home_dir/.config/autostart"

cat > "$icon_dir/nexos-emulator-center.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#111827"/>
      <stop offset="1" stop-color="#020617"/>
    </linearGradient>
    <linearGradient id="a" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#22c55e"/>
      <stop offset="1" stop-color="#38bdf8"/>
    </linearGradient>
  </defs>
  <rect x="8" y="8" width="112" height="112" rx="28" fill="url(#bg)" stroke="#22c55e" stroke-width="4"/>
  <rect x="29" y="47" width="70" height="38" rx="16" fill="none" stroke="url(#a)" stroke-width="7"/>
  <circle cx="82" cy="66" r="5" fill="#e8f7ff"/>
  <circle cx="94" cy="60" r="5" fill="#e8f7ff"/>
  <path d="M43 66 h18 M52 57 v18" stroke="#e8f7ff" stroke-width="6" stroke-linecap="round"/>
  <circle cx="99" cy="29" r="8" fill="#38bdf8" opacity=".9"/>
</svg>
SVG

cat > "$emu_dir/emulator_catalog.json" <<'JSON'
{
  "version": 1,
  "rom_root": "~/Games/NexOS/ROMs",
  "bios_root": "~/Games/NexOS/BIOS",
  "save_root": "~/Games/NexOS/Saves",
  "systems": [
    {"id": "retroarch", "name": "RetroArch", "commands": ["retroarch"], "type": "multi-system frontend"},
    {"id": "dolphin", "name": "Dolphin", "commands": ["dolphin-emu", "dolphin"], "type": "GameCube / Wii emulator"},
    {"id": "pcsx2", "name": "PCSX2", "commands": ["pcsx2"], "type": "PlayStation 2 emulator"},
    {"id": "ppsspp", "name": "PPSSPP", "commands": ["ppsspp", "PPSSPPSDL"], "type": "PSP emulator"},
    {"id": "mame", "name": "MAME", "commands": ["mame"], "type": "Arcade emulator"},
    {"id": "dosbox", "name": "DOSBox", "commands": ["dosbox"], "type": "DOS emulator"},
    {"id": "mednafen", "name": "Mednafen", "commands": ["mednafen"], "type": "multi-system emulator"},
    {"id": "scummvm", "name": "ScummVM", "commands": ["scummvm"], "type": "classic adventure game interpreter"},
    {"id": "fsuae", "name": "FS-UAE", "commands": ["fs-uae", "fs-uae-launcher"], "type": "Amiga emulator"},
    {"id": "hatari", "name": "Hatari", "commands": ["hatari"], "type": "Atari ST/STE/TT/Falcon emulator"},
    {"id": "mupen64plus", "name": "Mupen64Plus", "commands": ["mupen64plus"], "type": "Nintendo 64 emulator"},
    {"id": "mgba", "name": "mGBA", "commands": ["mgba-qt", "mgba"], "type": "Game Boy Advance emulator"}
  ]
}
JSON

cat > /usr/local/bin/nexos-emulator-center <<'PY'
#!/usr/bin/env python3
from __future__ import annotations
import json, os, shutil, subprocess, tkinter as tk
from pathlib import Path
from tkinter import ttk, messagebox

APP_DIR = Path('/opt/nexos/emulator-center')
CATALOG = APP_DIR / 'emulator_catalog.json'
GAME_ROOT = Path.home() / 'Games' / 'NexOS'
ROM_ROOT = GAME_ROOT / 'ROMs'
BIOS_ROOT = GAME_ROOT / 'BIOS'
SAVE_ROOT = GAME_ROOT / 'Saves'
SHOT_ROOT = GAME_ROOT / 'Screenshots'
CONFIG_ROOT = GAME_ROOT / 'Configs'

for p in (ROM_ROOT, BIOS_ROOT, SAVE_ROOT, SHOT_ROOT, CONFIG_ROOT):
    p.mkdir(parents=True, exist_ok=True)


def load_catalog():
    try:
        return json.loads(CATALOG.read_text(encoding='utf-8'))
    except Exception:
        return {'systems': []}


def installed(commands):
    for raw in commands:
        exe = raw.split()[0]
        if shutil.which(exe):
            return raw
    return None


def run(commands):
    cmd = installed(commands)
    if not cmd:
        messagebox.showwarning('NexOS Emulator Center', 'This emulator is not installed in this ISO build. It may not be available in the current Debian repository/component set.')
        return
    subprocess.Popen(cmd.split(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def open_path(path: Path):
    path.mkdir(parents=True, exist_ok=True)
    subprocess.Popen(['xdg-open', str(path)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def controller_test():
    for cmd in (['jstest-gtk'], ['x-terminal-emulator', '-e', 'bash', '-lc', 'ls /dev/input/js* 2>/dev/null; echo; echo Press Enter to close; read']):
        if shutil.which(cmd[0]):
            subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return
    messagebox.showinfo('Controller Test', 'No controller tester found.')

catalog = load_catalog()
root = tk.Tk()
root.title('NexOS Emulator Center')
root.geometry('1040x700')
root.configure(bg='#07111f')
root.minsize(900, 600)
try:
    ttk.Style(root).theme_use('clam')
except Exception:
    pass

header = tk.Frame(root, bg='#07111f', padx=22, pady=18)
header.pack(fill='x')
tk.Label(header, text='NexOS Emulator Center', bg='#07111f', fg='#e8f7ff', font=('Sans', 28, 'bold')).pack(side='left')
tk.Label(header, text='No ROMs, BIOS, keys, or copyrighted game files are included.', bg='#07111f', fg='#9bd5ff', font=('Sans', 11)).pack(side='right')

main = tk.Frame(root, bg='#07111f', padx=18, pady=12)
main.pack(fill='both', expand=True)
left = tk.Frame(main, bg='#0d172b', padx=12, pady=12, highlightbackground='#294866', highlightthickness=1)
left.pack(side='left', fill='y', padx=(0, 12))
right = tk.Frame(main, bg='#07111f')
right.pack(side='left', fill='both', expand=True)

for label, path in [('Open ROMs Folder', ROM_ROOT), ('Open BIOS Folder', BIOS_ROOT), ('Open Saves Folder', SAVE_ROOT), ('Open Screenshots', SHOT_ROOT), ('Open Configs', CONFIG_ROOT)]:
    tk.Button(left, text=label, command=lambda p=path: open_path(p), bg='#1f2937', fg='#e8f7ff', activebackground='#0ea5e9', relief='flat', padx=14, pady=10, width=22).pack(fill='x', pady=5)

tk.Button(left, text='Controller Test', command=controller_test, bg='#14532d', fg='#e8f7ff', activebackground='#16a34a', relief='flat', padx=14, pady=10, width=22).pack(fill='x', pady=(18, 5))

notice = tk.Label(left, text='Legal note:\nUse only games/BIOS\nyou own or have rights to use.', justify='left', bg='#0d172b', fg='#a7bdd8', wraplength=210)
notice.pack(fill='x', pady=(18, 0))

canvas = tk.Canvas(right, bg='#07111f', highlightthickness=0)
scroll = ttk.Scrollbar(right, orient='vertical', command=canvas.yview)
list_frame = tk.Frame(canvas, bg='#07111f')
list_frame.bind('<Configure>', lambda _e: canvas.configure(scrollregion=canvas.bbox('all')))
canvas.create_window((0, 0), window=list_frame, anchor='nw')
canvas.configure(yscrollcommand=scroll.set)
canvas.pack(side='left', fill='both', expand=True)
scroll.pack(side='right', fill='y')

systems = catalog.get('systems', [])
for i, item in enumerate(systems):
    card = tk.Frame(list_frame, bg='#0d172b', padx=14, pady=12, highlightbackground='#294866', highlightthickness=1)
    card.grid(row=i, column=0, sticky='ew', pady=6, padx=4)
    list_frame.grid_columnconfigure(0, weight=1)
    cmd = installed(item.get('commands', []))
    status = 'Installed' if cmd else 'Not installed / unavailable'
    status_color = '#86efac' if cmd else '#fbbf24'
    tk.Label(card, text=item.get('name', item.get('id', 'Unknown')), bg='#0d172b', fg='#e8f7ff', font=('Sans', 15, 'bold')).grid(row=0, column=0, sticky='w')
    tk.Label(card, text=item.get('type', ''), bg='#0d172b', fg='#a7bdd8', font=('Sans', 10)).grid(row=1, column=0, sticky='w', pady=(2, 0))
    tk.Label(card, text=status, bg='#0d172b', fg=status_color, font=('Sans', 10, 'bold')).grid(row=0, column=1, sticky='e', padx=12)
    tk.Button(card, text='Launch', command=lambda c=item.get('commands', []): run(c), bg='#0ea5e9', fg='white', relief='flat', padx=18, pady=7).grid(row=1, column=1, sticky='e', padx=12)
    card.grid_columnconfigure(0, weight=1)

root.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-emulator-center

cat > /usr/local/bin/nexos-emulator-scan <<'PY'
#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import json, shutil
catalog_path = Path('/opt/nexos/emulator-center/emulator_catalog.json')
rom_root = Path.home() / 'Games' / 'NexOS' / 'ROMs'
rom_root.mkdir(parents=True, exist_ok=True)
cat = json.loads(catalog_path.read_text()) if catalog_path.exists() else {'systems': []}
print('NexOS Emulator Scan')
print('====================')
print(f'ROM folder: {rom_root}')
print()
for item in cat.get('systems', []):
    found = next((c for c in item.get('commands', []) if shutil.which(c.split()[0])), None)
    print(f"{item.get('name')}: {'installed as ' + found if found else 'not installed'}")
print()
print('No ROMs/BIOS are included. Add your own legal files to the ROMs/BIOS folders.')
PY
chmod 0755 /usr/local/bin/nexos-emulator-scan

cat > /usr/share/applications/nexos-emulator-center.desktop <<'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=NexOS Emulator Center
Comment=Launch and manage legal emulators and ROM folders
Exec=nexos-emulator-center
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-emulator-center.svg
Terminal=false
StartupNotify=false
Categories=Game;Emulator;
X-XFCE-Trusted=true
DESKTOP
chmod 0755 /usr/share/applications/nexos-emulator-center.desktop

cat > /usr/share/applications/nexos-emulator-scan.desktop <<'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=NexOS Emulator Scan
Comment=Show installed emulator status
Exec=sh -c 'x-terminal-emulator -e nexos-emulator-scan'
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-emulator-center.svg
Terminal=false
StartupNotify=false
Categories=Game;Emulator;
X-XFCE-Trusted=true
DESKTOP
chmod 0755 /usr/share/applications/nexos-emulator-scan.desktop

# Add emulator center to the NexOS native dock if the dock exists.
if [[ -f /usr/local/bin/nexos-dock ]]; then
  python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock')
s=p.read_text()
old='''    ("Terminal", ["xfce4-terminal"]),\n]'''
new='''    ("Terminal", ["xfce4-terminal"]),\n    ("Emulators", ["nexos-emulator-center"]),\n]'''
if old in s and 'nexos-emulator-center' not in s:
    p.write_text(s.replace(old,new))
PY
  chmod 0755 /usr/local/bin/nexos-dock
fi

# Add emulator commands to the AI assistant catalog if present.
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then
  python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json')
data=json.loads(p.read_text())
data['emulator center']={'label':'NexOS Emulator Center','commands':['nexos-emulator-center'],'permission':'app.open'}
data['emulators']={'label':'NexOS Emulator Center','commands':['nexos-emulator-center'],'permission':'app.open'}
data['retroarch']={'label':'RetroArch','commands':['retroarch'],'permission':'app.open'}
data['dolphin']={'label':'Dolphin','commands':['dolphin-emu','dolphin'],'permission':'app.open'}
data['pcsx2']={'label':'PCSX2','commands':['pcsx2'],'permission':'app.open'}
data['mame']={'label':'MAME','commands':['mame'],'permission':'app.open'}
data['dosbox']={'label':'DOSBox','commands':['dosbox'],'permission':'app.open'}
p.write_text(json.dumps(data, indent=2))
PY
fi

cat > /opt/nexos/NexOS_AI_Assistant/skills/emulator-center.skill.json <<'JSON'
{
  "id": "emulator-center",
  "name": "Emulator Center",
  "description": "Opens NexOS Emulator Center and whitelisted installed emulators.",
  "intents": ["app.open"],
  "examples": ["Hey NexOS open emulator center", "Hey NexOS open retroarch", "Hey NexOS open dolphin"]
}
JSON

cat > /usr/share/nexos/NEXOS_EMULATOR_CENTER.md <<'MD'
# NexOS Emulator Center

NexOS includes emulator tooling, launchers, folders, controller testing, and a safe emulator hub.

Included/attempted packages depend on what is available from the build repository:

- RetroArch and libretro cores
- Dolphin
- PCSX2
- PPSSPP
- MAME
- DOSBox
- Mednafen
- ScummVM
- FS-UAE
- Hatari
- Mupen64Plus
- mGBA

NexOS does **not** include ROMs, BIOS files, keys, firmware dumps, or copyrighted games.
Use only files you own or have legal permission to use.

Folders:

- `~/Games/NexOS/ROMs`
- `~/Games/NexOS/BIOS`
- `~/Games/NexOS/Saves`
- `~/Games/NexOS/Screenshots`
- `~/Games/NexOS/Configs`

Commands:

```bash
nexos-emulator-center
nexos-emulator-scan
```

Assistant examples:

```bash
nexos-command-router "hey nexos open emulator center" --json
nexos-command-router "hey nexos open retroarch" --json
```
MD

cat >> /usr/share/nexos/app-map.txt <<'APPMAP_APPEND'

NexOS Emulator Center:
- Native Emulator Center GUI.
- Legal ROM/BIOS/Saves/Screenshots/Configs folder structure.
- Attempts installation of open-source emulators from the Debian repositories.
- Adds emulator app launchers and assistant skill/catalog entries.
- Adds controller test helper.
- Does not include ROMs, BIOS files, keys, or copyrighted game files.
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
  -e "s/__EDITION_LABEL__/$EDITION_LABEL/g" \
  "$LB_CONFIG_DIR/hooks/normal/160-nexos-emulator-center.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/160-nexos-emulator-center.hook.chroot"

success "Injected NexOS Emulator Center for $NEXOS_EDITION."
