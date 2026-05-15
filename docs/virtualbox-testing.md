# NexOS VirtualBox Testing Guide

## Recommended VM Profile

- Type: Linux
- Version: Debian 64-bit
- RAM: 4096 MB minimum, 8192 MB recommended
- CPUs: 2 minimum, 4 recommended
- Disk: 40 GB dynamically allocated VDI
- Graphics Controller: VMSVGA
- Video Memory: 128 MB
- Network: NAT
- Audio: Intel HDA/default
- Firmware: EFI for the current profile
- ISO: `iso/nexos-origin-amd64.iso`

These values are controlled in:

```text
build-config/nexos.conf
testing/virtualbox-profile.conf
```

## Automated VM Workflow

After building the ISO:

```bash
make validate-iso
make vbox-create
make vbox-status
make vbox-start
```

During testing:

```bash
make vbox-screenshot
make vbox-logs
```

Reset to the clean snapshot:

```bash
make vbox-reset
```

Delete the VM:

```bash
make vbox-clean
```

Attach a rebuilt ISO to the existing VM:

```bash
make vbox-attach-iso
```

## Manual Test Steps

1. Boot from the ISO.
2. Select the live boot entry if the menu appears.
3. Confirm the desktop loads.
4. Open terminal.
5. Run:

```bash
nexos-info
```

6. Open file manager.
7. Open browser.
8. Test network:

```bash
ping -c 3 deb.debian.org
```

9. Test compiler tools:

```bash
cat > /tmp/hello.cpp <<'CPP'
#include <iostream>
int main(){ std::cout << "NexOS compiler test\n"; }
CPP
g++ /tmp/hello.cpp -o /tmp/hello
/tmp/hello
```

10. Capture evidence from the host:

```bash
make vbox-screenshot
make vbox-logs
```

## Part 3 Checklist

Use the full checklist here:

```text
testing/checklists/live-iso-boot-checklist.md
```

Minimum pass requirements:

- [ ] ISO boots.
- [ ] Boot menu appears.
- [ ] XFCE desktop loads.
- [ ] Autologin works.
- [ ] Mouse works.
- [ ] Keyboard works.
- [ ] Network adapter appears.
- [ ] Terminal opens.
- [ ] File manager opens.
- [ ] Browser opens.
- [ ] Screenshot capture works.
- [ ] Log collection works.
- [ ] Shutdown works.

## Troubleshooting

### Black screen

Try VMSVGA with 128 MB VRAM. If that fails, edit `build-config/nexos.conf` and change:

```text
VBOX_FIRMWARE="bios"
```

Then recreate the VM:

```bash
make vbox-clean
make vbox-create
make vbox-start
```

### ISO not booting

Run:

```bash
make validate-iso
```

Then rebuild:

```bash
make clean-full
make iso
make validate-iso
make vbox-clean
make vbox-create
```

### No internet

The VM uses NAT by default. Inside NexOS, test:

```bash
ip addr
ping -c 3 1.1.1.1
ping -c 3 deb.debian.org
```

### No audio

The VM uses Intel HDA/default audio. Confirm host audio works, then check inside the live desktop with `pavucontrol`.

### Slow performance

Increase CPUs to 4 and RAM to 8192 MB. Keep animations minimal until later desktop polish parts.

### Shared clipboard not working

The VM profile enables bidirectional clipboard, but stronger VirtualBox guest utilities are planned for Part 20. For now, use screenshots and logs for evidence capture.

### Need evidence for a bug report

Run:

```bash
make vbox-screenshot
make vbox-logs
```

Attach files from:

```text
build/virtualbox/
```
