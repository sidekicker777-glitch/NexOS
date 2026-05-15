# NexOS Live ISO Boot Checklist

Use this checklist every time you rebuild the ISO during early development.

## Host-Side Checks

- [ ] `make part3-verify` passes.
- [ ] `make iso` completes without errors.
- [ ] `make validate-iso` confirms checksum and boot catalog.
- [ ] `make vbox-create` creates or recreates the VM.
- [ ] `make vbox-status` shows the VM exists.

## Boot Checks

- [ ] VirtualBox starts without an error dialog.
- [ ] NexOS ISO is attached as the optical drive.
- [ ] VM boots from DVD/ISO first.
- [ ] Boot menu appears.
- [ ] No kernel panic appears.
- [ ] No endless boot loop occurs.
- [ ] Live desktop loads.
- [ ] LightDM autologin succeeds.

## Desktop Checks

- [ ] Mouse works.
- [ ] Keyboard works.
- [ ] Display resolution is usable.
- [ ] Taskbar/panel appears.
- [ ] Desktop shortcut appears.
- [ ] File manager opens.
- [ ] Terminal opens.
- [ ] Browser opens.
- [ ] Shutdown/restart menu works.

## System Checks Inside NexOS

Run inside the live terminal:

```bash
nexos-info
ip addr
ping -c 3 deb.debian.org
```

Compiler smoke test:

```bash
cat > /tmp/hello.cpp <<'CPP'
#include <iostream>
int main(){ std::cout << "NexOS compiler test\\n"; }
CPP
g++ /tmp/hello.cpp -o /tmp/hello
/tmp/hello
```

Archive tool smoke test:

```bash
mkdir -p /tmp/nexos-archive-test
echo "NexOS archive test" > /tmp/nexos-archive-test/readme.txt
7z a /tmp/nexos-test.7z /tmp/nexos-archive-test >/tmp/nexos-7z.log
7z t /tmp/nexos-test.7z
```

## Evidence Capture

While the VM is running, run on the host:

```bash
make vbox-screenshot
make vbox-logs
```

Save the screenshot and log folder when reporting a failure.

## Result

- [ ] PASS: ISO reaches the live desktop and core apps work.
- [ ] FAIL: Attach the screenshot and files from `build/virtualbox/` to the issue notes.
