# NexOS Part 9 - Main OS and Security OS focus

Goal: pause the broad Tools edition as the main development focus and build NexOS around two primary editions:

1. **NexOS Main** - the clean daily-use operating system.
2. **NexOS Security** - the same clean OS plus security/admin hardening tools.

The Tools edition can stay available as an optional experiment, but new core work should focus on Main and Security first.

## Main OS focus

NexOS Main should feel like its own operating system, not just Debian with apps installed.

### Main OS priorities

- Clean desktop layout.
- Fast boot and lightweight desktop.
- Original NexOS branding and wallpaper.
- NexOS Welcome app.
- NexOS Control Center.
- NexOS Code Editor launcher.
- NexOS Extractor for archives.
- NexOS System Report.
- File manager defaults and shortcuts.
- Browser and common daily-use tools.
- Development basics for scripting and compiling.
- Installer support later.

### Main OS rule

Main should stay clean. Do not overload it with huge optional app packs. Large tools should be optional through separate editions or later through a NexOS App Center.

## Security OS focus

NexOS Security should be based on the Main OS first. It should not become a totally different OS.

### Security OS priorities

- Everything from Main.
- NexOS Security Center.
- Firewall controls.
- AppArmor visibility and profiles where available.
- Audit tools.
- Integrity checking.
- Sandboxing options.
- Security reports.
- Admin-focused shortcuts.
- Clear explanation that this is not a certified government/security OS unless formally certified later.

### Security OS rule

Security edition should add protection and admin tools without breaking normal desktop use.

## Open-source tool rule

NexOS can use open-source software as a foundation, but the user experience should be wrapped, configured, and organized by NexOS:

- Use open-source tools where they are strong.
- Configure them for NexOS defaults.
- Add NexOS launchers and wrappers.
- Build original NexOS tools when an open-source foundation does not fit.
- Keep licenses and upstream credits clear.
- Never copy proprietary branding or restricted assets.

## Editions going forward

```text
main      = primary clean OS
security  = primary security/admin OS
tools     = optional broad app/tool experiment, not the current main focus
```

## Next implementation targets

1. Add NexOS Control Center to Main and Security.
2. Add NexOS Extractor to Main and Security.
3. Add NexOS App Map / Credits to Main and Security.
4. Improve NexOS Code Editor wrapper.
5. Improve desktop layout and settings defaults.
6. Keep Security Center only in Security.
7. Keep large optional tool packs out of Main.
