# NexOS Part 5 - Security and open-source tool direction

Goal: keep the original NexOS plan and add a stronger security-focused desktop using only legal open-source packages available from Debian repositories.

## Direction

NexOS will stay Debian-based and legally original. The desktop will keep moving toward a familiar Windows-like layout while adding built-in security and system tools.

## Features to build into NexOS

### Desktop
- Familiar bottom panel layout.
- Welcome center.
- System report shortcut.
- File manager, browser, code editor, office tools, archive tools, printer/scanner basics.
- Original NexOS branding and artwork only.

### Security
- NexOS Security Center GUI/CLI.
- Tiered profiles: Basic, Enhanced, Maximum.
- AppArmor status and tools where available.
- Firewall status and UFW integration where available.
- Audit logging tools where available.
- Integrity checking with AIDE where available.
- Optional sandbox tools such as Firejail and Bubblewrap where available.
- Optional auditing tools such as Lynis and OpenSCAP where available.

## Part 5 build change

The ISO build now injects a NexOS Security Center and optional open-source security packages. Package installation is guarded so missing packages should not break the entire ISO build.

Live credentials:

```text
Username: nexos
Password: nexos
```

After booting, run:

```bash
nexos-info
nexos-security-center
nexos-system-report
```
