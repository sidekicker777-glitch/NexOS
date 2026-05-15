# NexOS Build Setup Guide

## Recommended Build Host

Best option:

- Debian 13 Trixie x86_64 VM or real machine

Also workable:

- Ubuntu 24.04/26.04 host, but Debian 13 is preferred because the target image is Debian 13.

Avoid using Windows directly for the ISO build. WSL2 can prepare files, but live ISO builds are more reliable inside a real Debian VM.

## Install Build Dependencies

```bash
make deps
```

This installs:

- live-build
- debootstrap
- squashfs-tools
- xorriso
- syslinux tools
- mtools/dosfstools
- QEMU test tools
- supporting CLI utilities

VirtualBox is not installed automatically because packages differ by host. Install it separately if you want VirtualBox GUI testing.

## Part 2 Build Flow

```bash
make check
make deps
make init
make part2-verify
make iso
make validate-iso
```

## Folder Structure

```text
NexOS/
├── build-config/              # Single source of truth for build settings
├── docs/                      # Part docs, roadmap, VirtualBox workflow
├── iso/                       # Generated ISO output
├── live-build/                # Debian live-build workspace/config
├── scripts/                   # Build and setup automation
│   └── lib/                   # Shared script helpers
├── testing/                   # QEMU/VirtualBox testing tools
├── workspace/                 # Scratch workspace, ignored by git
├── Makefile                   # Main command entrypoint
└── README.md
```

## Common Build Errors

### `lb: command not found`

Run:

```bash
make deps
```

### Host codename warning

The scripts target Debian 13 Trixie. Building from a different distro can work, but Debian 13 is the cleanest setup.

### Build fails midway

Run:

```bash
make clean
make iso
```

If that still fails:

```bash
make clean-full
make init
make iso
```

### ISO is missing after build

Check:

```bash
cat build/logs/live-build-part2.log
```
