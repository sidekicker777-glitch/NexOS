# Part 1: Build Environment and Live-Build Foundation

## Part Number

Part 1

## Goal

Create a clean NexOS build foundation that can be expanded into a bootable live ISO in Part 2.

This part sets:

- Current base distro choice
- Build settings
- Required folder structure
- Host dependency installer
- Host validation script
- live-build initializer
- VirtualBox testing profile notes

## Recommended Base OS

Use **Debian 13 Trixie** for NexOS.

Why:

- Debian 13 is current stable.
- live-build is Debian's native live ISO workflow.
- It is lightweight and easier to strip down than a full Ubuntu desktop.
- It gives better control over what packages go into the ISO.
- It supports legally clean custom branding and distro work.

Ubuntu 26.04 LTS is also current, but its default desktop target is heavier. NexOS can still support Ubuntu packages or PPAs later where legally appropriate, but the base should stay Debian-first for this lightweight OS.

## Recommended Desktop Strategy

Start with a minimal XFCE desktop in Part 2/Part 5, then customize panels, menu, settings, and branding. Build original NexOS apps later instead of trying to create a full desktop shell from scratch on day one.

## Recommended Build Tools

- Bash scripts for automation
- Debian live-build for live ISO generation
- debootstrap for root filesystem creation under live-build
- xorriso/squashfs-tools/syslinux/grub for ISO creation
- QEMU for quick boot tests
- VirtualBox for user-facing VM testing

## Recommended Programming Languages

- Bash: build automation
- Python: helper tools and metadata scripts
- C/C++ with Qt or GTK: native settings/developer apps later
- HTML/CSS/JS only for optional web-like UI pieces, not as a required local server

## Files Created

```text
build-config/nexos.conf
scripts/lib/common.sh
scripts/00-host-check.sh
scripts/01-install-host-deps.sh
scripts/02-init-live-build.sh
scripts/03-clean.sh
scripts/04-part1-verify.sh
docs/part-01-build-environment.md
docs/roadmap.md
docs/virtualbox-testing.md
testing/virtualbox-profile.conf
.gitignore
Makefile
README.md
```

## Files Changed

```text
Makefile
README.md
```

## Build Commands

```bash
make check
make deps
make init
make part1-verify
```

## Run Commands

Part 1 does not boot an ISO yet. It prepares the build workspace.

Run this to inspect config:

```bash
make show-config
```

## VirtualBox Test Steps

Part 1 has no ISO yet, so VirtualBox is not started in this part.

Confirm the VM profile exists:

```bash
cat testing/virtualbox-profile.conf
```

## Test Checklist

- `make check` runs and prints host status.
- `make deps` installs required build packages.
- `make init` creates `live-build/config/`.
- `live-build/config/package-lists/00-nexos-base.list.chroot` exists.
- `live-build/config/includes.chroot/etc/nexos-release` exists.
- `make part1-verify` passes.

## What Should Happen If It Works

You should see:

```text
[OK] Part 1 verification passed.
```

The project is ready for Part 2, where the first bootable live ISO is built.

## Common Errors and Fixes

### `lb: command not found`

Run:

```bash
make deps
```

### Not enough disk space

Free at least 35GB. 50GB is better.

### Running as root warning

Use a normal user account. The scripts use `sudo` only where needed.

### VirtualBox command missing

Install VirtualBox separately. Part 1 does not require it, but later testing does.
