#!/usr/bin/env bash
# NexOS Gaming Mode Center integration.
# Adds a real open-source gaming/emulation control hub: performance helpers, controller tools,
# ROM scanner, Vulkan/OpenGL checks, RetroArch config seeding, and AI/app launch integration.
# No ROMs, BIOS files, keys, firmware dumps, or copyrighted games are included.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

NEXOS_EDITION="${NEXOS_EDITION:-main}"
EDITION_LABEL="${EDITION_LABEL:-NexOS Main}"

ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"

cat > "$LB_CONFIG_DIR/package-lists/59-nexos-gaming-mode-center.list.chroot" <<'PKGS'
# NexOS Gaming Mode Center base support.
python3
python3-tk
xdg-utils
libnotify-bin
procps
pciutils
usbutils
mesa-utils
mesa-vulkan-drivers
vulkan-tools
joystick
jstest-gtk
evtest
p7zip-full
unzip
zip
PKGS

cat > "$LB_CONFIG_DIR/hooks/normal/180-nexos-gaming-mode-center.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
game_dir="/opt/nexos/gaming-mode-center"
icon_dir="/usr/share/icons/hicolor/scalable/apps"

install_if_available() {
  local pkg="$1"
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    apt-get install -y --no-install-recommends "$pkg" || true
  fi
}

apt-get update || true
for pkg in \
  python3 python3-tk xdg-utils libnotify-bin procps pciutils usbutils \
  mesa-utils mesa-vulkan-drivers vulkan-tools joystick jstest-gtk evtest \
  p7zip-full unzip zip gamemode mangohud goverlay antimicrox; do
  install_if_available "$pkg"
done

mkdir -p \
  "$game_dir" \
  "$game_dir/profiles" \
  "$icon_dir" \
  /usr/local/bin \
  /usr/share/applications \
  /usr/share/nexos \
  "$home_dir/Games/NexOS/ROMs" \
  "$home_dir/Games/NexOS/ROMs/Arcade" \
  "$home_dir/Games/NexOS/ROMs/Atari" \
  "$home_dir/Games/NexOS/ROMs/DOS" \
  "$home_dir/Games/NexOS/ROMs/GameBoy" \
  "$home_dir/Games/NexOS/ROMs/GameBoyAdvance" \
  "$home_dir/Games/NexOS/ROMs/GameCube" \
  "$home_dir/Games/NexOS/ROMs/NES" \
  "$home_dir/Games/NexOS/ROMs/Nintendo64" \
  "$home_dir/Games/NexOS/ROMs/PlayStation" \
  "$home_dir/Games/NexOS/ROMs/PlayStation2" \
  "$home_dir/Games/NexOS/ROMs/PSP" \
  "$home_dir/Games/NexOS/ROMs/Sega" \
  "$home_dir/Games/NexOS/ROMs/SNES" \
  "$home_dir/Games/NexOS/ROMs/Wii" \
  "$home_dir/Games/NexOS/Saves" \
  "$home_dir/Games/NexOS/Screenshots" \
  "$home_dir/Games/NexOS/Configs" \
  "$home_dir/.config/retroarch" \
  "$home_dir/.config/nexos/gaming"

cat > "$icon_dir/nexos-gaming-center.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#111827"/><stop offset="1" stop-color="#020617"/></linearGradient>
    <linearGradient id="a" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#a78bfa"/><stop offset="1" stop-color="#22c55e"/></linearGradient>
  </defs>
  <rect x="8" y="8" width="112" height="112" rx="28" fill="url(#bg)" stroke="#a78bfa" stroke-width="4"/>
  <rect x="27" y="49" width="74" height="36" rx="17" fill="none" stroke="url(#a)" stroke-width="7"/>
  <path d="M42 67 h19 M51.5 57.5 v19" stroke="#e8f7ff" stroke-width="6" stroke-linecap="round"/>
  <circle cx="80" cy="67" r="5" fill="#e8f7ff"/>
  <circle cx="93" cy="60" r="5" fill="#e8f7ff"/>
  <path d="M35 40 C42 24 87 24 94 40" fill="none" stroke="#38bdf8" stroke-width="5" stroke-linecap="round" opacity=".85"/>
</svg>
SVG

cat > "$game_dir/profiles/gaming_profiles.json" <<'JSON'
{
  "version": 1,
  "legal_note": "NexOS does not include ROMs, BIOS files, keys, firmware dumps, or copyrighted games.",
  "folders": {
    "roms": "~/Games/NexOS/ROMs",
    "bios": "~/Games/NexOS/BIOS",
    "saves": "~/Games/NexOS/Saves",
    "screenshots": "~/Games/NexOS/Screenshots",
    "configs": "~/Games/NexOS/Configs"
  },
  "profiles": {
    "balanced": {"description": "Default safe profile for battery/VM use."},
    "performance": {"description": "Uses gamemoderun when available and opens performance monitor helpers."},
    "debug": {"description": "Shows Vulkan/OpenGL/controller diagnostics."}
  }
}
JSON

# Seed a safe RetroArch config. RetroArch can overwrite/expand it later.
cat > "$home_dir/.config/retroarch/retroarch.cfg" <<'CFG'
# NexOS RetroArch starter config. Safe defaults only.
# Add your own legal ROMs and BIOS files under ~/Games/NexOS.
video_driver = "gl"
audio_driver = "pulse"
rgui_browser_directory = "~/Games/NexOS/ROMs"
system_directory = "~/Games/NexOS/BIOS"
savefile_directory = "~/Games/NexOS/Saves"
savestate_directory = "~/Games/NexOS/Saves"
screenshot_directory = "~/Games/NexOS/Screenshots"
video_fullscreen = "false"
menu_show_core_updater = "false"
confirm_on_exit = "true"
CFG

cat > /usr/local/bin/nexos-game-scan <<'PY'
#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import json, shutil, subprocess, sys

ROOT = Path.home() / 'Games' / 'NexOS'
ROMS = ROOT / 'ROMs'
BIOS = ROOT / 'BIOS'
EXTS = {
    '.nes':'NES', '.fds':'NES', '.sfc':'SNES', '.smc':'SNES', '.gb':'GameBoy', '.gbc':'GameBoy', '.gba':'GameBoyAdvance',
    '.n64':'Nintendo64', '.z64':'Nintendo64', '.v64':'Nintendo64', '.iso':'Disc Image', '.cue':'Disc Image', '.chd':'Disc Image',
    '.cso':'PSP', '.pbp':'PlayStation/PSP', '.zip':'Archive/Arcade', '.7z':'Archive', '.md':'Sega', '.bin':'Disc/Binary',
    '.gen':'Sega', '.sms':'Sega', '.gg':'Sega', '.32x':'Sega', '.wad':'Wii', '.rvz':'GameCube/Wii', '.gcm':'GameCube',
    '.dol':'GameCube/Wii', '.elf':'Executable'
}
for p in (ROMS, BIOS, ROOT/'Saves', ROOT/'Screenshots', ROOT/'Configs'):
    p.mkdir(parents=True, exist_ok=True)

items = []
for file in ROMS.rglob('*'):
    if file.is_file():
        kind = EXTS.get(file.suffix.lower(), 'Unknown')
        items.append({'file': str(file.relative_to(ROMS)), 'type': kind, 'size_mb': round(file.stat().st_size / (1024*1024), 2)})

print('NexOS Game Scan')
print('===============')
print(f'ROM folder: {ROMS}')
print(f'BIOS folder: {BIOS}')
print()
if not items:
    print('No game files found. Add your own legal files to the ROMs folder.')
else:
    for item in items:
        print(f"{item['file']} | {item['type']} | {item['size_mb']} MB")

report = ROOT / 'game-scan-report.json'
report.write_text(json.dumps({'rom_root': str(ROMS), 'bios_root': str(BIOS), 'items': items}, indent=2), encoding='utf-8')
print(f'\nReport written: {report}')
PY
chmod 0755 /usr/local/bin/nexos-game-scan

cat > /usr/local/bin/nexos-game-health <<'PY'
#!/usr/bin/env python3
from __future__ import annotations
import shutil, subprocess

checks = [
    ('OpenGL info', ['glxinfo', '-B']),
    ('Vulkan devices', ['vulkaninfo', '--summary']),
    ('PCI devices', ['lspci']),
    ('USB devices', ['lsusb']),
]
print('NexOS Gaming Health')
print('===================')
for title, cmd in checks:
    print('\n## ' + title)
    if not shutil.which(cmd[0]):
        print(f'{cmd[0]} is not installed.')
        continue
    try:
        out = subprocess.check_output(cmd, text=True, stderr=subprocess.STDOUT, timeout=8)
        print(out[:5000])
    except Exception as exc:
        print(exc)
print('\nGameMode:', 'installed' if shutil.which('gamemoderun') else 'not installed')
print('MangoHud:', 'installed' if shutil.which('mangohud') else 'not installed')
print('Controller tester:', 'installed' if shutil.which('jstest-gtk') else 'not installed')
PY
chmod 0755 /usr/local/bin/nexos-game-health

cat > /usr/local/bin/nexos-gaming-center <<'PY'
#!/usr/bin/env python3
from __future__ import annotations
import shutil, subprocess, tkinter as tk
from pathlib import Path
from tkinter import ttk, messagebox

ROOT = Path.home() / 'Games' / 'NexOS'
ROMS = ROOT / 'ROMs'
BIOS = ROOT / 'BIOS'
SAVES = ROOT / 'Saves'
SHOTS = ROOT / 'Screenshots'
CONFIGS = ROOT / 'Configs'
for p in (ROMS, BIOS, SAVES, SHOTS, CONFIGS):
    p.mkdir(parents=True, exist_ok=True)

def run(cmds):
    if isinstance(cmds, str):
        cmds = [cmds]
    for raw in cmds:
        exe = raw.split()[0]
        if shutil.which(exe):
            subprocess.Popen(raw.split(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True
    messagebox.showwarning('NexOS Gaming Center', 'Tool is not installed in this ISO build or is unavailable in the repo.')
    return False

def open_path(path: Path):
    path.mkdir(parents=True, exist_ok=True)
    subprocess.Popen(['xdg-open', str(path)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def term(cmd: str):
    for t in ('xfce4-terminal', 'x-terminal-emulator'):
        if shutil.which(t):
            subprocess.Popen([t, '-e', 'bash', '-lc', cmd + '; echo; echo Press Enter to close; read'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return
    subprocess.Popen(['sh', '-lc', cmd], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

root = tk.Tk()
root.title('NexOS Gaming Center')
root.geometry('1060x720')
root.configure(bg='#07111f')
root.minsize(900, 620)
try:
    ttk.Style(root).theme_use('clam')
except Exception:
    pass

header = tk.Frame(root, bg='#07111f', padx=22, pady=18)
header.pack(fill='x')
tk.Label(header, text='NexOS Gaming Center', bg='#07111f', fg='#e8f7ff', font=('Sans', 28, 'bold')).pack(side='left')
tk.Label(header, text='Emulation, controllers, performance, diagnostics', bg='#07111f', fg='#9bd5ff', font=('Sans', 11)).pack(side='right')

notebook = ttk.Notebook(root)
notebook.pack(fill='both', expand=True, padx=18, pady=(0, 18))

def tab(name):
    f = tk.Frame(notebook, bg='#07111f', padx=16, pady=16)
    notebook.add(f, text=name)
    return f

quick = tab('Quick Launch')
buttons = [
    ('Emulator Center', lambda: run('nexos-emulator-center')),
    ('BIOS Manager', lambda: run('nexos-bios-manager')),
    ('RetroArch', lambda: run(['retroarch'])),
    ('Dolphin', lambda: run(['dolphin-emu','dolphin'])),
    ('PCSX2', lambda: run(['pcsx2'])),
    ('PPSSPP', lambda: run(['ppsspp','PPSSPPSDL'])),
    ('MAME', lambda: run(['mame'])),
    ('DOSBox', lambda: run(['dosbox'])),
]
for i,(label,cmd) in enumerate(buttons):
    b=tk.Button(quick,text=label,command=cmd,bg='#1f2937',fg='#e8f7ff',activebackground='#0ea5e9',relief='flat',padx=18,pady=14,font=('Sans',11,'bold'))
    b.grid(row=i//4,column=i%4,padx=8,pady=8,sticky='ew')
    quick.grid_columnconfigure(i%4,weight=1)

folders = tab('Folders')
for i,(label,path) in enumerate([('ROMs',ROMS),('BIOS',BIOS),('Saves',SAVES),('Screenshots',SHOTS),('Configs',CONFIGS)]):
    tk.Button(folders,text='Open '+label,command=lambda p=path: open_path(p),bg='#1f2937',fg='#e8f7ff',activebackground='#0ea5e9',relief='flat',padx=18,pady=14).grid(row=i,column=0,padx=8,pady=8,sticky='ew')
    tk.Label(folders,text=str(path),bg='#07111f',fg='#a7bdd8',anchor='w').grid(row=i,column=1,padx=8,pady=8,sticky='ew')
folders.grid_columnconfigure(1,weight=1)

controllers = tab('Controllers')
for i,(label,cmds) in enumerate([('Controller Tester',['jstest-gtk']),('Input Event Viewer',['x-terminal-emulator -e evtest']),('AntiMicroX Mapper',['antimicrox'])]):
    tk.Button(controllers,text=label,command=lambda c=cmds: run(c),bg='#14532d',fg='#e8f7ff',activebackground='#16a34a',relief='flat',padx=18,pady=14).pack(fill='x',pady=8)
tk.Label(controllers,text='Plug in your controller, then run Controller Tester. For VirtualBox, pass USB controller devices through from Devices > USB.',bg='#07111f',fg='#a7bdd8',wraplength=780,justify='left').pack(fill='x',pady=15)

diag = tab('Diagnostics')
for label,cmd in [('Game Scan','nexos-game-scan'),('Gaming Health','nexos-game-health'),('Vulkan Summary','vulkaninfo --summary'),('OpenGL Summary','glxinfo -B'),('GPU Info','nexos-gpu-info')]:
    tk.Button(diag,text=label,command=lambda c=cmd: term(c),bg='#312e81',fg='#e8f7ff',activebackground='#4f46e5',relief='flat',padx=18,pady=13).pack(fill='x',pady=7)

perf = tab('Performance')
tk.Label(perf,text='NexOS uses safe helper tools when installed. GameMode and MangoHud are open-source tools and may be available depending on repo support.',bg='#07111f',fg='#a7bdd8',wraplength=860,justify='left').pack(fill='x',pady=10)
for label,cmd in [('Check GameMode','gamemoded -t'),('Open MangoHud Overlay Config','goverlay'),('Show Running Processes','ps aux --sort=-%cpu | head -25')]:
    tk.Button(perf,text=label,command=lambda c=cmd: term(c),bg='#713f12',fg='#e8f7ff',activebackground='#ca8a04',relief='flat',padx=18,pady=13).pack(fill='x',pady=7)

root.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-gaming-center

cat > /usr/share/applications/nexos-gaming-center.desktop <<'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=NexOS Gaming Center
Comment=NexOS gaming, emulation, controller, and performance hub
Exec=nexos-gaming-center
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-gaming-center.svg
Terminal=false
StartupNotify=false
Categories=Game;Emulator;System;
X-XFCE-Trusted=true
DESKTOP
chmod 0755 /usr/share/applications/nexos-gaming-center.desktop

cat > /usr/share/applications/nexos-game-scan.desktop <<'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=NexOS Game Scan
Comment=Scan legal ROM folders and write a report
Exec=sh -c 'x-terminal-emulator -e nexos-game-scan'
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-gaming-center.svg
Terminal=false
StartupNotify=false
Categories=Game;Emulator;
X-XFCE-Trusted=true
DESKTOP
chmod 0755 /usr/share/applications/nexos-game-scan.desktop

cat > /usr/share/applications/nexos-game-health.desktop <<'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=NexOS Gaming Health
Comment=Show GPU, Vulkan, OpenGL, controller, and GameMode status
Exec=sh -c 'x-terminal-emulator -e nexos-game-health'
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-gaming-center.svg
Terminal=false
StartupNotify=false
Categories=Game;System;
X-XFCE-Trusted=true
DESKTOP
chmod 0755 /usr/share/applications/nexos-game-health.desktop

# Add Gaming Center to the native dock if the dock exists.
if [[ -f /usr/local/bin/nexos-dock ]]; then
  python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock')
s=p.read_text()
if 'nexos-gaming-center' not in s:
    old='''    ("BIOS", ["nexos-bios-manager"]),\n]'''
    new='''    ("BIOS", ["nexos-bios-manager"]),\n    ("Gaming", ["nexos-gaming-center"]),\n]'''
    if old in s:
        s=s.replace(old,new)
    else:
        s=s.replace(']', '    ("Gaming", ["nexos-gaming-center"]),\n]', 1)
    p.write_text(s)
PY
  chmod 0755 /usr/local/bin/nexos-dock
fi

# Add assistant catalog entries and skill if the assistant exists.
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then
  python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json')
data=json.loads(p.read_text())
for key,cmd,label in [
    ('gaming center','nexos-gaming-center','NexOS Gaming Center'),
    ('game scan','x-terminal-emulator -e nexos-game-scan','NexOS Game Scan'),
    ('gaming health','x-terminal-emulator -e nexos-game-health','NexOS Gaming Health')
]:
    data[key]={'label':label,'commands':[cmd],'permission':'app.open'}
p.write_text(json.dumps(data, indent=2))
PY
fi

if [[ -d /opt/nexos/NexOS_AI_Assistant/skills ]]; then
  cat > /opt/nexos/NexOS_AI_Assistant/skills/gaming-center.skill.json <<'JSON'
{
  "id": "gaming-center",
  "name": "Gaming Center",
  "description": "Opens NexOS Gaming Center, scans legal game folders, and runs gaming diagnostics.",
  "intents": ["app.open"],
  "examples": ["Hey NexOS open gaming center", "Hey NexOS open game scan", "Hey NexOS open gaming health"]
}
JSON
fi

cat > /usr/share/nexos/NEXOS_GAMING_MODE_CENTER.md <<'MD'
# NexOS Gaming Center

NexOS Gaming Center is the main gaming/emulation hub.

It provides:

- Emulator Center launcher
- BIOS Manager launcher
- Legal ROM folder scanner
- Controller tester shortcut
- Vulkan/OpenGL/GPU diagnostics
- GameMode/MangoHud checks when those open-source packages are available
- RetroArch safe starter config
- NexOS Assistant command catalog integration

Folders:

- `~/Games/NexOS/ROMs`
- `~/Games/NexOS/BIOS`
- `~/Games/NexOS/Saves`
- `~/Games/NexOS/Screenshots`
- `~/Games/NexOS/Configs`

Commands:

```bash
nexos-gaming-center
nexos-game-scan
nexos-game-health
```

Assistant examples:

```bash
nexos-command-router "hey nexos open gaming center" --json
nexos-command-router "hey nexos open game scan" --json
nexos-command-router "hey nexos open gaming health" --json
```

NexOS does not include ROMs, BIOS files, keys, firmware dumps, or copyrighted games.
MD

cat >> /usr/share/nexos/app-map.txt <<'APPMAP_APPEND'

NexOS Gaming Center:
- Adds gaming/emulation hub GUI.
- Adds legal ROM folder scanner and report generator.
- Adds gaming health diagnostics for GPU, Vulkan, OpenGL, GameMode, MangoHud, and controllers.
- Adds safe RetroArch starter config using NexOS folders.
- Adds assistant commands and dock entry.
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
  "$LB_CONFIG_DIR/hooks/normal/180-nexos-gaming-mode-center.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/180-nexos-gaming-mode-center.hook.chroot"

success "Injected NexOS Gaming Mode Center for $NEXOS_EDITION."
