# NexOS Part 8 - Core NexOS apps over open-source foundations

Goal: keep building NexOS as its own OS, not just a pile of apps. Open-source software is used as the foundation, then NexOS adds wrappers, launchers, presets, branding, and easier workflows.

## Apps added in this part

### NexOS Control Center
A single NexOS launcher for common system settings:

- Settings Manager
- Display settings
- Appearance settings
- Network connections
- Power settings
- Printer settings
- Disk utility
- Task manager
- System report
- NexOS Toolbox
- NexOS Code Editor

### NexOS Extractor
A simple extraction wrapper for common archive formats using open-source tools already available in the ISO where possible:

- 7z / 7za / 7zz
- unzip
- bsdtar
- tar

The goal is to make archive extraction feel built into NexOS instead of making users remember terminal commands.

### NexOS App Map
A local text page that explains which open-source foundations are being used and how they are integrated into NexOS.

## Edition rule

- Main stays clean.
- Tools adds broad optional open-source app packs.
- Security stays separate.

## Next steps

- Replace more raw app shortcuts with NexOS-branded launchers.
- Add a real GUI App Center later.
- Add NexOS default presets for Blender, editors, file tools, and system tools.
- Keep avoiding proprietary/copied branding and restricted assets.
