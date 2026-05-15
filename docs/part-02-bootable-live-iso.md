# Part 2: First Bootable Live ISO

## Part Number

2

## Goal

Create the first NexOS live ISO build workflow using Debian live-build. This part adds a minimal graphical live desktop that can boot in a VM, show the XFCE desktop, open terminal/file manager/browser, and run basic developer/archive tools.

## Files Created

```text
scripts/05-build-live-iso.sh
scripts/06-validate-iso.sh
scripts/07-part2-verify.sh
testing/qemu-live-smoke-test.sh
testing/create-vbox-vm.sh
docs/part-02-bootable-live-iso.md
live-build/config/package-lists/00-nexos-live-core.list.chroot
live-build/config/package-lists/10-nexos-desktop-xfce.list.chroot
live-build/config/package-lists/20-nexos-tools.list.chroot
live-build/config/package-lists/30-nexos-vm-support.list.chroot
live-build/config/includes.chroot/etc/lightdm/lightdm.conf.d/50-nexos-live-autologin.conf
live-build/config/includes.chroot/etc/nexos-release
live-build/config/includes.chroot/etc/skel/Desktop/README-NexOS.txt
live-build/config/includes.chroot/etc/skel/Desktop/NexOS-Info.desktop
live-build/config/includes.chroot/usr/local/bin/nexos-info
live-build/config/includes.chroot/usr/share/applications/nexos-info.desktop
live-build/config/includes.chroot/usr/share/backgrounds/nexos/nexos-origin.svg
live-build/config/includes.chroot/usr/share/nexos/LEGAL.txt
live-build/config/hooks/normal/010-nexos-live-polish.hook.chroot
```

## Files Changed

```text
README.md
Makefile
build-config/nexos.conf
docs/build-setup.md
docs/roadmap.md
docs/virtualbox-testing.md
scripts/00-host-check.sh
scripts/01-install-host-deps.sh
scripts/02-init-live-build.sh
scripts/03-clean.sh
scripts/04-part1-verify.sh
testing/virtualbox-profile.conf
```

## Full Build Commands

```bash
make check
make deps
make init
make part2-verify
make iso
make validate-iso
```

## Run Commands

After the ISO is built:

```bash
make qemu-test
```

Or create a VirtualBox VM:

```bash
./testing/create-vbox-vm.sh
VBoxManage startvm "NexOS-Test" --type gui
```

## Expected ISO Output

```text
iso/nexos-origin-amd64.iso
iso/nexos-origin-amd64.iso.sha256
```

## VirtualBox Test Steps

1. Create a new VM.
2. Type: Linux.
3. Version: Debian 64-bit.
4. RAM: 4096 MB minimum, 8192 MB recommended.
5. CPU: 2 cores minimum, 4 recommended.
6. Disk: 40 GB dynamically allocated VDI.
7. Graphics Controller: VMSVGA.
8. Video Memory: 128 MB.
9. Network: NAT.
10. Firmware: EFI for this early profile.
11. Mount `iso/nexos-origin-amd64.iso` as the optical drive.
12. Boot the VM.
13. Choose the live boot entry.
14. Wait for LightDM/XFCE.

## Test Checklist

- [ ] ISO file exists in `iso/`.
- [ ] SHA256 checksum validates.
- [ ] VM boots from the ISO.
- [ ] Boot menu appears.
- [ ] Live desktop loads.
- [ ] User autologin works or login is recoverable.
- [ ] Terminal opens.
- [ ] File manager opens.
- [ ] `nexos-info` prints release data.
- [ ] Network adapter is detected.
- [ ] Browser opens.
- [ ] Archive tools are installed.
- [ ] GCC/G++/CMake are installed.
- [ ] Shutdown/reboot works.

## What Should Happen If It Works

The VM should boot into a basic XFCE desktop with NexOS release files, a desktop README, original NexOS wallpaper assets, and core tools installed.

## Common Errors and Fixes

### Black screen after boot

Try disabling EFI in the VM, or switch the VirtualBox graphics controller between VMSVGA and VBoxSVGA. Keep video memory at 128 MB.

### ISO does not boot

Run:

```bash
make validate-iso
```

Then rebuild cleanly:

```bash
make clean-full
make iso
```

### No internet in live mode

Use NAT networking first. In the live desktop, open terminal and run:

```bash
nmcli dev status
sudo systemctl restart NetworkManager
```

### Autologin fails

Try username `nexos` and a blank password. If it still fails, press Ctrl+Alt+F2 and check LightDM logs later in Part 3.

### Package not found during build

Run on Debian 13 Trixie when possible. Then:

```bash
sudo apt update
make clean-full
make iso
```

### Build interrupted

```bash
make clean
make iso
```


## Next Step

Part 3 adds the stronger VirtualBox automation: VM create/start/stop/reset/status commands, screenshot capture, log collection, and a repeatable live ISO checklist.
