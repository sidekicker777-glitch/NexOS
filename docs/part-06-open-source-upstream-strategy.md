# NexOS Part 6 - Open-source upstream strategy

Goal: NexOS should not just install random apps. NexOS should use strong open-source projects as foundations, customize them for the OS, improve the user experience, and only build new tools from scratch when no good open-source base fits.

## Core rule

1. Prefer open-source upstream projects with clear licenses and active maintenance.
2. Package, configure, theme, and integrate them into NexOS first.
3. If an app is good but not beginner-friendly, wrap it with a NexOS GUI or NexOS preset system.
4. If no good open-source base exists, build an original NexOS app.
5. Never copy proprietary branding, closed-source assets, paid apps, ROMs, BIOS files, or restricted code.
6. Keep license notices and source links for anything NexOS modifies or redistributes.

## Main edition direction

The main NexOS ISO should stay clean and useful. It should not include the extra security stack by default.

Main edition should focus on:

- Clean desktop experience
- File management
- Built-in archive/extractor tools
- Code editor and compilers
- Browser
- Office/document basics
- Media playback
- System settings
- App store/package manager frontend later
- Optional gaming/emulation tooling only when legal and user-provided content rules are clear

## Security edition direction

The security edition is separate and optional. It can include firewall, AppArmor tools, audit tools, integrity checking, and security-center features.

## Open-source projects to build from first

### Desktop shell and UI
- XFCE components as the first lightweight desktop foundation.
- Whisker Menu for a more familiar launcher.
- Papirus icons and Arc theme as open-source visual foundations.
- Later: build original NexOS Settings and NexOS Welcome apps to make the desktop feel custom.

### File manager
- Start with Thunar.
- Add NexOS presets, context-menu actions, archive shortcuts, terminal-open shortcuts, and beginner-friendly defaults.
- Later: if Thunar cannot be shaped enough, build a custom NexOS File Manager.

### Archive/extractor
- Use 7zip, libarchive/bsdtar, unzip, zip, and xarchiver.
- Add a NexOS Extract app that gives one simple GUI for ZIP, 7z, TAR, RAR-read where legal packages support it, and common formats.

### Code editor and compiler tools
- Start with Geany because it is lightweight and open-source.
- Include GCC, G++, make, cmake, ninja, gdb, Python, and Git.
- Later: build NexCode as a custom editor/IDE if Geany cannot deliver the wanted experience.

### Browser
- Start with Firefox ESR from Debian.
- Add NexOS bookmarks, homepage, privacy defaults, and import helper later.

### Media
- Use VLC for playback.
- Optional future creator edition can build from OBS Studio, Kdenlive, Audacity, FFmpeg, and HandBrake/encoding libraries.

### Office and documents
- Use LibreOffice basics for documents, spreadsheets, and presentations.
- Later add a NexOS document helper/welcome templates app.

### System tools
- Use GParted, fastfetch/neofetch, lshw, inxi, USB tools, printer/scanner tools when available.
- Build NexOS System Report as the user-friendly front end.

## Build rule for future parts

Every future NexOS feature should be classified as one of these:

```text
UPSTREAM_CUSTOMIZED = use an open-source project and customize/integrate it
NEXOS_WRAPPER = create an easier NexOS GUI around open-source command-line tools
NEXOS_ORIGINAL = build a new app when no good open-source foundation exists
NOT_ALLOWED = proprietary, copied, cracked, restricted, or unclear license
```

## Next implementation steps

1. Keep `main` as the clean default ISO.
2. Keep `security` as a separate optional ISO.
3. Add a NexOS Open Source Credits page.
4. Add a NexOS App Map that tracks what each built-in app is based on.
5. Add a NexOS Extractor wrapper around 7zip/libarchive.
6. Add a NexOS Control Center wrapper for system settings.
7. Add a NexOS Package Center later for installing/removing optional tool packs.
