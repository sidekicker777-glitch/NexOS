#!/usr/bin/env bash
# NexOS BIOS Manager integration.
# Adds legal BIOS management tools only: import, folder setup, scanner, checklist, and docs.
# This does NOT include BIOS files, firmware dumps, encryption keys, console keys, or copyrighted game/system files.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

NEXOS_EDITION="${NEXOS_EDITION:-main}"
EDITION_LABEL="${EDITION_LABEL:-NexOS Main}"

ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"

cat > "$LB_CONFIG_DIR/package-lists/58-nexos-bios-manager.list.chroot" <<'PKGS'
# NexOS BIOS Manager support.
python3
python3-tk
xdg-utils
libnotify-bin
p7zip-full
unzip
zip
PKGS

cat > "$LB_CONFIG_DIR/hooks/normal/170-nexos-bios-manager.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
bios_dir="/opt/nexos/bios-manager"
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
  "$bios_dir" \
  "$icon_dir" \
  /usr/local/bin \
  /usr/share/applications \
  /usr/share/nexos \
  "$home_dir/Games/NexOS/BIOS" \
  "$home_dir/Games/NexOS/BIOS/PlayStation" \
  "$home_dir/Games/NexOS/BIOS/PlayStation2" \
  "$home_dir/Games/NexOS/BIOS/PSP" \
  "$home_dir/Games/NexOS/BIOS/Sega" \
  "$home_dir/Games/NexOS/BIOS/Nintendo" \
  "$home_dir/Games/NexOS/BIOS/Arcade" \
  "$home_dir/Games/NexOS/BIOS/Computer" \
  "$home_dir/Games/NexOS/BIOS/Imported"

cat > "$icon_dir/nexos-bios-manager.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#111827"/>
      <stop offset="1" stop-color="#020617"/>
    </linearGradient>
    <linearGradient id="a" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#facc15"/>
      <stop offset="1" stop-color="#38bdf8"/>
    </linearGradient>
  </defs>
  <rect x="8" y="8" width="112" height="112" rx="28" fill="url(#bg)" stroke="#facc15" stroke-width="4"/>
  <rect x="31" y="36" width="66" height="56" rx="10" fill="none" stroke="url(#a)" stroke-width="7"/>
  <path d="M44 53 h40 M44 67 h40 M44 81 h28" stroke="#e8f7ff" stroke-width="6" stroke-linecap="round"/>
  <circle cx="96" cy="30" r="8" fill="#38bdf8" opacity=".9"/>
</svg>
SVG

cat > "$bios_dir/bios_manifest.json" <<'JSON'
{
  "version": 1,
  "root": "~/Games/NexOS/BIOS",
  "legal_note": "NexOS does not include BIOS files. Import only BIOS/firmware you personally own or have legal permission to use.",
  "systems": [
    {
      "id": "ps1",
      "name": "PlayStation",
      "folder": "PlayStation",
      "notes": "Some PS1 cores/emulators work better with a real BIOS. Add your legally obtained SCPH BIOS files here."
    },
    {
      "id": "ps2",
      "name": "PlayStation 2",
      "folder": "PlayStation2",
      "notes": "PCSX2 requires a legally dumped PS2 BIOS from your own console."
    },
    {
      "id": "psp",
      "name": "PSP",
      "folder": "PSP",
      "notes": "PPSSPP usually does not need a separate BIOS for normal use."
    },
    {
      "id": "sega",
      "name": "Sega systems",
      "folder": "Sega",
      "notes": "Add legally obtained Sega CD/Saturn/Dreamcast BIOS files if your emulator/core requires them."
    },
    {
      "id": "nintendo",
      "name": "Nintendo systems",
      "folder": "Nintendo",
      "notes": "Some systems may use firmware files. Use only files you dumped from your own hardware."
    },
    {
      "id": "arcade",
      "name": "Arcade/MAME",
      "folder": "Arcade",
      "notes": "MAME may require device/BIOS ZIPs for some arcade systems. Use only legal dumps."
    },
    {
      "id": "computer",
      "name": "Classic computers",
      "folder": "Computer",
      "notes": "Some computer emulators require Kickstart/TOS/ROM files. Use only legal dumps."
    }
  ]
}
JSON

cat > /usr/local/bin/nexos-bios-manager <<'PY'
#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, os, shutil, subprocess, tkinter as tk
from pathlib import Path
from tkinter import ttk, filedialog, messagebox

APP_DIR = Path('/opt/nexos/bios-manager')
MANIFEST = APP_DIR / 'bios_manifest.json'
BIOS_ROOT = Path.home() / 'Games' / 'NexOS' / 'BIOS'
BIOS_ROOT.mkdir(parents=True, exist_ok=True)

try:
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
except Exception:
    manifest = {'systems': []}

for item in manifest.get('systems', []):
    (BIOS_ROOT / item.get('folder', item.get('id', 'Other'))).mkdir(parents=True, exist_ok=True)
(BIOS_ROOT / 'Imported').mkdir(parents=True, exist_ok=True)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def open_path(path: Path):
    path.mkdir(parents=True, exist_ok=True)
    subprocess.Popen(['xdg-open', str(path)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def scan_files() -> list[tuple[str, str, str, int]]:
    out = []
    for p in BIOS_ROOT.rglob('*'):
        if p.is_file() and p.name.lower() not in {'readme.txt', 'bios-report.txt'}:
            rel = str(p.relative_to(BIOS_ROOT))
            try:
                out.append((rel, sha256(p)[:16], p.suffix.lower() or '(none)', p.stat().st_size))
            except Exception:
                out.append((rel, 'error', p.suffix.lower() or '(none)', 0))
    return out


def refresh_table():
    for row in table.get_children():
        table.delete(row)
    for rel, digest, ext, size in scan_files():
        table.insert('', 'end', values=(rel, ext, f'{size // 1024} KB', digest))


def import_files():
    files = filedialog.askopenfilenames(title='Import legally owned BIOS/firmware files')
    if not files:
        return
    dest = BIOS_ROOT / 'Imported'
    dest.mkdir(parents=True, exist_ok=True)
    copied = 0
    for f in files:
        src = Path(f)
        if src.is_file():
            target = dest / src.name
            if target.exists():
                target = dest / f'{src.stem}_{int(target.stat().st_mtime)}{src.suffix}'
            shutil.copy2(src, target)
            copied += 1
    refresh_table()
    messagebox.showinfo('NexOS BIOS Manager', f'Imported {copied} file(s) into {dest}.')


def write_report():
    report = BIOS_ROOT / 'bios-report.txt'
    lines = ['NexOS BIOS Manager Report', '=' * 27, '', 'Legal note: NexOS does not include BIOS files. Use only files you own or have permission to use.', '']
    for rel, digest, ext, size in scan_files():
        lines.append(f'{rel} | {ext} | {size} bytes | sha256-start {digest}')
    if len(lines) <= 5:
        lines.append('No BIOS/firmware files found.')
    report.write_text('\n'.join(lines), encoding='utf-8')
    open_path(BIOS_ROOT)

root = tk.Tk()
root.title('NexOS BIOS Manager')
root.geometry('980x660')
root.configure(bg='#07111f')
root.minsize(850, 560)
try:
    ttk.Style(root).theme_use('clam')
except Exception:
    pass

header = tk.Frame(root, bg='#07111f', padx=22, pady=18)
header.pack(fill='x')
tk.Label(header, text='NexOS BIOS Manager', bg='#07111f', fg='#e8f7ff', font=('Sans', 28, 'bold')).pack(side='left')
tk.Label(header, text='Import your own legal BIOS/firmware files. None are included.', bg='#07111f', fg='#facc15', font=('Sans', 11, 'bold')).pack(side='right')

main = tk.Frame(root, bg='#07111f', padx=18, pady=10)
main.pack(fill='both', expand=True)
left = tk.Frame(main, bg='#0d172b', padx=12, pady=12, highlightbackground='#294866', highlightthickness=1)
left.pack(side='left', fill='y', padx=(0, 12))
right = tk.Frame(main, bg='#07111f')
right.pack(side='left', fill='both', expand=True)

buttons = [
    ('Import BIOS Files', import_files),
    ('Open BIOS Folder', lambda: open_path(BIOS_ROOT)),
    ('Open Imported Folder', lambda: open_path(BIOS_ROOT / 'Imported')),
    ('Write BIOS Report', write_report),
    ('Refresh Scan', refresh_table),
]
for label, command in buttons:
    tk.Button(left, text=label, command=command, bg='#1f2937', fg='#e8f7ff', activebackground='#0ea5e9', relief='flat', padx=14, pady=10, width=22).pack(fill='x', pady=5)

tk.Label(left, text='Suggested folders', bg='#0d172b', fg='#e8f7ff', font=('Sans', 12, 'bold')).pack(anchor='w', pady=(20, 6))
for item in manifest.get('systems', []):
    folder = item.get('folder', item.get('id', 'Other'))
    tk.Button(left, text=folder, command=lambda f=folder: open_path(BIOS_ROOT / f), bg='#111827', fg='#c7d2fe', activebackground='#312e81', relief='flat', padx=10, pady=7, width=22).pack(fill='x', pady=2)

note = tk.Label(left, text='NexOS cannot ship BIOS files. Dump them from your own hardware or use files you have legal rights to use.', justify='left', bg='#0d172b', fg='#a7bdd8', wraplength=220)
note.pack(fill='x', pady=(18, 0))

cols = ('File', 'Type', 'Size', 'SHA256 preview')
table = ttk.Treeview(right, columns=cols, show='headings')
for col in cols:
    table.heading(col, text=col)
    table.column(col, width=160 if col != 'File' else 380)
table.pack(fill='both', expand=True)

bottom = tk.Label(right, text='Tip: Put BIOS files in the matching folder, then configure the emulator/core to use that folder if needed.', bg='#07111f', fg='#9bd5ff', anchor='w')
bottom.pack(fill='x', pady=(10, 0))
refresh_table()
root.mainloop()
PY
chmod 0755 /usr/local/bin/nexos-bios-manager

cat > /usr/local/bin/nexos-bios-scan <<'PY'
#!/usr/bin/env python3
from __future__ import annotations
import hashlib
from pathlib import Path
root = Path.home() / 'Games' / 'NexOS' / 'BIOS'
root.mkdir(parents=True, exist_ok=True)
print('NexOS BIOS Scan')
print('================')
print('Legal note: NexOS does not include BIOS files. Use only files you own or have permission to use.')
print(f'BIOS root: {root}')
print()
found = False
for p in root.rglob('*'):
    if p.is_file() and p.name.lower() != 'bios-report.txt':
        found = True
        h = hashlib.sha256()
        with p.open('rb') as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b''):
                h.update(chunk)
        print(f'{p.relative_to(root)} | {p.stat().st_size} bytes | sha256 {h.hexdigest()}')
if not found:
    print('No BIOS/firmware files found yet.')
PY
chmod 0755 /usr/local/bin/nexos-bios-scan

cat > /usr/share/applications/nexos-bios-manager.desktop <<'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=NexOS BIOS Manager
Comment=Import and organize your own legal emulator BIOS files
Exec=nexos-bios-manager
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-bios-manager.svg
Terminal=false
StartupNotify=false
Categories=Game;Emulator;Utility;
X-XFCE-Trusted=true
DESKTOP
chmod 0755 /usr/share/applications/nexos-bios-manager.desktop

cat > /usr/share/applications/nexos-bios-scan.desktop <<'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=NexOS BIOS Scan
Comment=Scan your legal BIOS folder
Exec=sh -c 'x-terminal-emulator -e nexos-bios-scan'
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-bios-manager.svg
Terminal=false
StartupNotify=false
Categories=Game;Emulator;Utility;
X-XFCE-Trusted=true
DESKTOP
chmod 0755 /usr/share/applications/nexos-bios-scan.desktop

# Add BIOS Manager to the native dock if the dock exists.
if [[ -f /usr/local/bin/nexos-dock ]]; then
  python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-dock')
s=p.read_text()
if 'nexos-bios-manager' not in s:
    old='''    ("Emulators", ["nexos-emulator-center"]),\n]'''
    new='''    ("Emulators", ["nexos-emulator-center"]),\n    ("BIOS", ["nexos-bios-manager"]),\n]'''
    if old in s:
        s=s.replace(old,new)
    else:
        s=s.replace(']', '    ("BIOS", ["nexos-bios-manager"]),\n]', 1)
    p.write_text(s)
PY
  chmod 0755 /usr/local/bin/nexos-dock
fi

# Add BIOS Manager to Emulator Center side menu if present.
if [[ -f /usr/local/bin/nexos-emulator-center ]]; then
  python3 - <<'PY' || true
from pathlib import Path
p=Path('/usr/local/bin/nexos-emulator-center')
s=p.read_text()
needle="('Open Configs', CONFIG_ROOT)"
replacement="('Open Configs', CONFIG_ROOT), ('Open BIOS Manager', Path.home() / 'Games' / 'NexOS' / 'BIOS')"
# Instead of opening the folder as a fake manager, add a real button after controller test.
if 'nexos-bios-manager' not in s:
    old="""tk.Button(left, text='Controller Test', command=controller_test, bg='#14532d', fg='#e8f7ff', activebackground='#16a34a', relief='flat', padx=14, pady=10, width=22).pack(fill='x', pady=(18, 5))"""
    new=old+"\n"+"""tk.Button(left, text='BIOS Manager', command=lambda: subprocess.Popen(['nexos-bios-manager'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL), bg='#713f12', fg='#e8f7ff', activebackground='#ca8a04', relief='flat', padx=14, pady=10, width=22).pack(fill='x', pady=5)"""
    if old in s:
        p.write_text(s.replace(old,new))
PY
  chmod 0755 /usr/local/bin/nexos-emulator-center
fi

# Add BIOS commands to the assistant catalog/skills if present.
if [[ -f /opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json ]]; then
  python3 - <<'PY' || true
from pathlib import Path
import json
p=Path('/opt/nexos/NexOS_AI_Assistant/integration/app_catalog.json')
data=json.loads(p.read_text())
data['bios manager']={'label':'NexOS BIOS Manager','commands':['nexos-bios-manager'],'permission':'app.open'}
data['bios']={'label':'NexOS BIOS Manager','commands':['nexos-bios-manager'],'permission':'app.open'}
data['bios scan']={'label':'NexOS BIOS Scan','commands':['x-terminal-emulator -e nexos-bios-scan'],'permission':'app.open'}
p.write_text(json.dumps(data, indent=2))
PY
fi

if [[ -d /opt/nexos/NexOS_AI_Assistant/skills ]]; then
  cat > /opt/nexos/NexOS_AI_Assistant/skills/bios-manager.skill.json <<'JSON'
{
  "id": "bios-manager",
  "name": "BIOS Manager",
  "description": "Opens NexOS BIOS Manager for importing and organizing legal emulator BIOS files.",
  "intents": ["app.open"],
  "examples": ["Hey NexOS open BIOS manager", "Hey NexOS open BIOS scan"]
}
JSON
fi

cat > /usr/share/nexos/NEXOS_BIOS_MANAGER.md <<'MD'
# NexOS BIOS Manager

NexOS includes a BIOS Manager to help organize emulator BIOS/firmware files.

Important: NexOS does **not** include BIOS files, firmware dumps, encryption keys, console keys, or copyrighted game/system files.

Use the manager to:

- Create BIOS folders
- Import your own legal BIOS files
- Scan files and generate SHA256 reports
- Open emulator BIOS folders quickly
- Connect BIOS management to Emulator Center and NexOS Assistant

Folders:

- `~/Games/NexOS/BIOS/PlayStation`
- `~/Games/NexOS/BIOS/PlayStation2`
- `~/Games/NexOS/BIOS/PSP`
- `~/Games/NexOS/BIOS/Sega`
- `~/Games/NexOS/BIOS/Nintendo`
- `~/Games/NexOS/BIOS/Arcade`
- `~/Games/NexOS/BIOS/Computer`
- `~/Games/NexOS/BIOS/Imported`

Commands:

```bash
nexos-bios-manager
nexos-bios-scan
```

Assistant examples:

```bash
nexos-command-router "hey nexos open bios manager" --json
nexos-command-router "hey nexos open bios scan" --json
```
MD

cat >> /usr/share/nexos/app-map.txt <<'APPMAP_APPEND'

NexOS BIOS Manager:
- Adds legal BIOS/firmware folder structure.
- Adds GUI import/scanner/report tool.
- Adds BIOS manager launchers and assistant skill/catalog entries.
- Does not include BIOS files, firmware dumps, encryption keys, console keys, or copyrighted system files.
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
  "$LB_CONFIG_DIR/hooks/normal/170-nexos-bios-manager.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/170-nexos-bios-manager.hook.chroot"

success "Injected NexOS BIOS Manager for $NEXOS_EDITION."
