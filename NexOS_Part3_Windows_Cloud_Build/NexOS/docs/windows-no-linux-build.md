# Build NexOS ISO from Windows Without a Linux Device

You do not need to own a Linux computer to build NexOS. The recommended Windows-friendly path is to let GitHub Actions build the ISO on a temporary Linux runner, then download the ISO artifact.

## Option A: GitHub Actions cloud build, recommended

This is the easiest path if you only have Windows.

### What you need

- A GitHub account.
- The NexOS project folder from this ZIP.
- Git installed on Windows, or you can upload the files through the GitHub website.

### Steps

1. Create a new GitHub repository named `NexOS`.
2. Upload the whole `NexOS` project folder to the repository.
3. Make sure this file exists in the repository:

```text
.github/workflows/build-nexos-iso.yml
```

4. Open the repository on GitHub.
5. Click **Actions**.
6. Click **Build NexOS ISO**.
7. Click **Run workflow**.
8. Wait for the workflow to finish.
9. Open the finished workflow run.
10. Download the artifact named:

```text
NexOS-live-ISO
```

11. Extract the downloaded artifact ZIP. You should get:

```text
nexos-origin-amd64.iso
nexos-origin-amd64.iso.sha256
```

## Option B: Windows WSL2 build

This runs Linux inside Windows. It is useful, but the GitHub Actions method is usually cleaner because ISO builders can need Linux mount/chroot behavior.

Open PowerShell as Administrator:

```powershell
wsl --install -d Debian
```

Restart if Windows asks you to. Then open Debian from the Start Menu and run:

```bash
sudo apt-get update
sudo apt-get install -y git make live-build debootstrap squashfs-tools xorriso syslinux-common syslinux-utils dosfstools mtools parted rsync
cd /mnt/c/Users/%USERNAME%/Downloads/NexOS
make check
make deps
make init
make iso
make validate-iso
```

If WSL fails because of mount/chroot restrictions, use Option A.

## Option C: Debian VM on Windows

You can install Debian inside VirtualBox on your Windows PC, then build NexOS inside that VM.

Recommended VM profile:

- OS Type: Debian 64-bit
- RAM: 8192 MB recommended
- CPU: 4 cores recommended
- Disk: 80 GB dynamically allocated VDI
- Network: NAT
- Graphics: VMSVGA

Inside the Debian VM:

```bash
sudo apt-get update
sudo apt-get install -y git make live-build debootstrap squashfs-tools xorriso syslinux-common syslinux-utils dosfstools mtools parted rsync
cd NexOS
make check
make deps
make init
make iso
make validate-iso
```

## How to test the ISO on Windows

After you download/build the ISO:

1. Open Oracle VirtualBox.
2. Create a new VM.
3. Type: Linux.
4. Version: Debian 64-bit.
5. RAM: 4096 MB minimum, 8192 MB recommended.
6. CPU: 2 minimum, 4 recommended.
7. Disk: 40 GB dynamically allocated VDI.
8. Graphics Controller: VMSVGA.
9. Video Memory: 128 MB.
10. Mount `nexos-origin-amd64.iso` as the optical drive.
11. Start the VM.

Expected result:

- The VM boots into the NexOS live desktop.
- The live user autologins to XFCE.
- The desktop shows NexOS info files.

## Common problems

### GitHub Actions says the workflow is disabled

Open the **Actions** tab and enable workflows for the repository.

### The workflow cannot find files

Make sure the files were uploaded with this structure:

```text
NexOS/
├── Makefile
├── build-config/
├── live-build/
├── scripts/
└── .github/workflows/build-nexos-iso.yml
```

If your repository root contains a folder named `NexOS`, open that folder and move its contents to the repository root.

### The artifact is a ZIP

That is normal. Download it and extract it. The ISO is inside.

### VirtualBox shows a black screen

Try these settings:

- Graphics Controller: VMSVGA
- Video Memory: 128 MB
- Disable 3D Acceleration for the first boot test
- Use BIOS boot first if EFI has issues

### The ISO file is missing after the build

Open the GitHub Actions log and check the `make iso` step. The expected output is:

```text
iso/nexos-origin-amd64.iso
```
