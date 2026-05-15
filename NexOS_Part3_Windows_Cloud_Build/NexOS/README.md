# NexOS

NexOS is an original lightweight Linux-based operating system project aimed at a familiar desktop workflow, strong VirtualBox testing, developer tools, and an optional console-style gaming mode.

The project uses **Debian 13 Trixie** and **Debian live-build** so NexOS can become a bootable live ISO without copying Windows, Batocera, or protected assets.

## Current Status

**Completed:**

- Part 1 — build environment, folder structure, host checks, dependency installer, and live-build initializer.
- Part 2 — first bootable live ISO workflow with XFCE, LightDM autologin config, live user files, NexOS release/legal files, original wallpaper, dev/archive tools, ISO checksum, ISO validation, QEMU smoke test, and VirtualBox checklist.
- Part 3 — stronger VirtualBox boot testing workflow with VM create/start/stop/reset/status helpers, screenshot capture, log collection, and a fixed live ISO checklist.
- Part 3 Windows/cloud helper — GitHub Actions workflow to build the ISO without owning a Linux device.

**Next:** Part 4 — original branding, boot screen, login screen, and wallpaper polish.

## Recommended Base

- Base OS: Debian 13 Trixie
- ISO builder: Debian live-build
- Desktop strategy: lightweight XFCE base first, custom NexOS shell/panels later
- Installer strategy: Calamares later, after the live ISO boots reliably
- Package manager: APT, with Flatpak optional later
- Primary languages: Bash for build automation, Python for helpers, C/C++/Qt or GTK for native apps later

## Main Commands

From the project root:

```bash
make check
make deps
make init
make part3-verify
make part3-cloud-verify
make iso
make validate-iso
```

Optional QEMU smoke test after building the ISO:

```bash
make qemu-test
```


## No Linux Device?

Use the included GitHub Actions workflow to build the ISO in the cloud from a Windows PC:

```text
.github/workflows/build-nexos-iso.yml
```

See:

```text
docs/windows-no-linux-build.md
```

The workflow uploads the finished ISO as an artifact named `NexOS-live-ISO`.

## ISO Output

After `make iso`, the ISO should be copied to:

```text
iso/nexos-origin-amd64.iso
iso/nexos-origin-amd64.iso.sha256
```

## Live Login

The live ISO is configured for:

```text
Username: nexos
Hostname: nexos-live
Desktop: XFCE through LightDM autologin
```

If a password prompt appears during early testing, try leaving the password blank first. A stricter installed-user flow will be added with the installer part later.

## Legal Rules

NexOS must stay original:

- No Windows names, icons, wallpapers, sounds, logos, or proprietary UI assets.
- No Batocera names, artwork, logos, or exact interface copying.
- No copyrighted ROMs, BIOS files, commercial games, cracks, or illegal download links.
- Optional third-party software must be clearly marked as user-installed.

## VirtualBox Test Commands

After building and validating the ISO:

```bash
make vbox-create
make vbox-start
make vbox-screenshot
make vbox-logs
```

Reset or delete the VM when needed:

```bash
make vbox-reset
make vbox-clean
```
