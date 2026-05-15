# Part 3: VirtualBox Boot Testing Workflow

## Part Number

Part 3

## Goal

Add a repeatable VirtualBox testing workflow for the NexOS live ISO so boot failures, display issues, network issues, and VM configuration problems can be captured instead of guessed.

Part 3 does not replace real human visual testing. It creates the VM, starts it, captures screenshots, gathers logs, and gives a fixed checklist to prove the ISO reached the live desktop.

## Files Created

```text
testing/vbox-lib.sh
testing/vbox-create.sh
testing/vbox-start.sh
testing/vbox-stop.sh
testing/vbox-reset.sh
testing/vbox-status.sh
testing/vbox-attach-iso.sh
testing/vbox-screenshot.sh
testing/vbox-collect-logs.sh
testing/vbox-clean.sh
testing/vbox-full-live-test.sh
testing/checklists/live-iso-boot-checklist.md
scripts/08-part3-verify.sh
docs/part-03-virtualbox-boot-testing.md
```

## Files Changed

```text
Makefile
README.md
build-config/nexos.conf
docs/roadmap.md
docs/virtualbox-testing.md
testing/create-vbox-vm.sh
```

## Required Host Tools

Install Oracle VirtualBox on the Linux build/test machine. The scripts call `VBoxManage`, which is the VirtualBox command-line tool.

Check it with:

```bash
VBoxManage --version
```

The Debian live-build documentation separates the host system that builds the live image from the target live system that boots it. Keep using a Debian-like host for `make iso`, then test the ISO in VirtualBox.

## Build Commands

```bash
make check
make deps
make init
make part3-verify
make iso
make validate-iso
```

## VirtualBox Run Commands

Create the VM:

```bash
make vbox-create
```

Start it in the GUI:

```bash
make vbox-start
```

Start it headless:

```bash
./testing/vbox-start.sh --headless
```

Capture a screenshot while the VM is running:

```bash
make vbox-screenshot
```

Collect logs:

```bash
make vbox-logs
```

Reset the VM to the fresh snapshot:

```bash
make vbox-reset
```

Attach a newly rebuilt ISO to the existing VM:

```bash
make vbox-attach-iso
```

Delete the VM:

```bash
make vbox-clean
```

## What Should Happen If It Works

1. `make vbox-create` creates a VM named `NexOS-Test`.
2. The VM uses Debian 64-bit type, VMSVGA graphics, NAT network, Intel HDA audio, 40 GB disk, and the generated NexOS ISO.
3. `make vbox-start` opens the VirtualBox VM window.
4. The NexOS ISO boot menu appears.
5. The live XFCE desktop loads.
6. The live user logs in automatically.
7. Terminal, file manager, browser, and `nexos-info` work.
8. `make vbox-screenshot` saves a PNG under `build/virtualbox/screenshots/`.
9. `make vbox-logs` saves host/VM reports under `build/virtualbox/`.

## Manual Live ISO Checklist

Use:

```text
testing/checklists/live-iso-boot-checklist.md
```

## Common Errors and Fixes

### `VBoxManage: command not found`

VirtualBox is not installed or not in `PATH`. Install VirtualBox from your distro packages or Oracle's official packages, then open a new terminal and try:

```bash
VBoxManage --version
```

### VM already exists

Reset or delete it:

```bash
make vbox-reset
```

or:

```bash
make vbox-clean
make vbox-create
```

### ISO missing

Build the ISO first:

```bash
make iso
make validate-iso
```

### Black screen

Try these in order:

1. Keep graphics controller set to `VMSVGA`.
2. Keep video memory at `128 MB`.
3. Try BIOS instead of EFI by editing `VBOX_FIRMWARE="bios"` in `build-config/nexos.conf`, then recreate the VM.
4. Boot again and collect logs:

```bash
make vbox-logs
```

### No internet inside live mode

The VM uses NAT by default. Check VirtualBox network adapter 1 is enabled. Then inside NexOS live mode:

```bash
ip addr
ping -c 3 1.1.1.1
ping -c 3 deb.debian.org
```

### Mouse capture or pointer issues

The VM is configured with USB tablet input. If the pointer still feels wrong, click the VM window, then use the VirtualBox Host key to release capture.

### Shared clipboard does not work

The VM profile enables bidirectional clipboard, but the guest needs proper guest integration tools. Stronger VirtualBox guest utilities are planned for Part 20.

## Part 3 Test Checklist

- [ ] `make part3-verify` passes.
- [ ] `make iso` creates `iso/nexos-origin-amd64.iso`.
- [ ] `make validate-iso` passes.
- [ ] `make vbox-create` creates the VM.
- [ ] `make vbox-status` shows VM details.
- [ ] `make vbox-start` starts the VM.
- [ ] Boot menu appears.
- [ ] Live desktop loads.
- [ ] Mouse works.
- [ ] Keyboard works.
- [ ] Terminal opens.
- [ ] `nexos-info` works.
- [ ] File manager opens.
- [ ] Network works.
- [ ] `make vbox-screenshot` saves a PNG.
- [ ] `make vbox-logs` saves VM logs.
- [ ] `make vbox-reset` restores the clean snapshot.

## Windows-only builder note

If you do not have a Linux device, use the included GitHub Actions cloud build workflow:

```text
.github/workflows/build-nexos-iso.yml
```

Full instructions are in:

```text
docs/windows-no-linux-build.md
```

Run the local verification command before uploading the project to GitHub if you are on Linux/WSL:

```bash
make part3-cloud-verify
```
