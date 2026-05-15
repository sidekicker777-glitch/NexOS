#!/usr/bin/env bash
# Initializes the Debian live-build workspace for NexOS Part 2.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_cmd lb

log "Initializing live-build workspace in $LIVE_BUILD_DIR"
ensure_dir "$LIVE_BUILD_DIR"

pushd "$LIVE_BUILD_DIR" >/dev/null

# live-build is safest when lb config is called once from a clean config.
rm -rf config

lb config \
  --mode debian \
  --distribution "$BASE_CODENAME" \
  --architectures "$BASE_ARCH" \
  --archive-areas "$BASE_ARCHIVE_AREAS" \
  --mirror-bootstrap "$MIRROR_BOOTSTRAP" \
  --mirror-chroot "$MIRROR_BOOTSTRAP" \
  --mirror-binary "$MIRROR_BINARY" \
  --mirror-chroot-security "$MIRROR_SECURITY" \
  --mirror-binary-security "$MIRROR_SECURITY" \
  --binary-images iso-hybrid \
  --debian-installer none \
  --bootloaders "syslinux,grub-efi" \
  --bootappend-live "boot=live components username=$LIVE_USERNAME hostname=$LIVE_HOSTNAME locales=$LIVE_LOCALE keyboard-layouts=$LIVE_KEYBOARD timezone=$LIVE_TIMEZONE user-default-groups=$LIVE_USER_GROUPS quiet splash" \
  --iso-volume "$ISO_VOLUME_ID" \
  --iso-application "$ISO_APPLICATION" \
  --iso-publisher "$ISO_PUBLISHER" \
  --iso-preparer "$ISO_PREPARER" \
  --image-name "${ISO_IMAGE_NAME%.iso}" \
  --apt-recommends false \
  --checksums sha256 \
  --firmware-binary true \
  --firmware-chroot true \
  --memtest none \
  --source false \
  --win32-loader false

ensure_dir "$LB_CONFIG_DIR/package-lists"
ensure_dir "$LB_CONFIG_DIR/includes.chroot/etc/lightdm/lightdm.conf.d"
ensure_dir "$LB_CONFIG_DIR/includes.chroot/etc/skel/Desktop"
ensure_dir "$LB_CONFIG_DIR/includes.chroot/etc/sudoers.d"
ensure_dir "$LB_CONFIG_DIR/includes.chroot/usr/local/bin"
ensure_dir "$LB_CONFIG_DIR/includes.chroot/usr/share/applications"
ensure_dir "$LB_CONFIG_DIR/includes.chroot/usr/share/backgrounds/nexos"
ensure_dir "$LB_CONFIG_DIR/includes.chroot/usr/share/nexos"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"

cat > "$LB_CONFIG_DIR/package-lists/00-nexos-live-core.list.chroot" <<'PKGS'
# NexOS Part 2: live boot core.
linux-image-amd64
live-boot
live-config
live-config-systemd
systemd-sysv
sudo
locales
tzdata
keyboard-configuration
console-setup
ca-certificates
PKGS

cat > "$LB_CONFIG_DIR/package-lists/10-nexos-desktop-xfce.list.chroot" <<'PKGS'
# NexOS Part 2: first lightweight graphical desktop.
xorg
lightdm
lightdm-gtk-greeter
xfce4
xfce4-terminal
thunar
mousepad
ristretto
xfce4-screenshooter
xfce4-taskmanager
network-manager
network-manager-gnome
wpasupplicant
wireless-tools
gvfs
gvfs-backends
polkitd
pkexec
dbus-x11
pipewire
pipewire-audio
pipewire-pulse
wireplumber
pavucontrol
PKGS

cat > "$LB_CONFIG_DIR/package-lists/20-nexos-tools.list.chroot" <<'PKGS'
# NexOS Part 2: useful default tools kept intentionally small.
bash-completion
curl
wget
nano
vim-tiny
less
htop
file
zip
unzip
7zip
libarchive-tools
xarchiver
firefox-esr
git
build-essential
gcc
g++
gdb
make
cmake
ninja-build
python3
python3-venv
PKGS

cat > "$LB_CONFIG_DIR/package-lists/30-nexos-vm-support.list.chroot" <<'PKGS'
# NexOS Part 2: virtual machine helper packages.
# VirtualBox guest X11 packages are not listed here because Debian stable may not ship them in all configurations.
# Part 20 will add stronger VirtualBox guest support once the base ISO is stable.
spice-vdagent
qemu-guest-agent
PKGS

cat > "$LB_CONFIG_DIR/includes.chroot/etc/nexos-release" <<RELEASE
NAME="$PROJECT_NAME"
ID=$PROJECT_ID
VERSION="$PROJECT_VERSION"
VERSION_CODENAME="$PROJECT_CODENAME"
BASE_VENDOR="$BASE_VENDOR"
BASE_CODENAME="$BASE_CODENAME"
ARCH="$BASE_ARCH"
RELEASE

cat > "$LB_CONFIG_DIR/includes.chroot/usr/share/nexos/LEGAL.txt" <<'LEGAL'
NexOS is an original Linux-based operating system project.
Do not include copied Windows, Batocera, Microsoft, Xbox, Steam, PlayStation, Nintendo, or other protected branding/assets.
Do not include copyrighted ROMs, BIOS files, commercial games, cracked software, or illegal downloads.
Only add software, artwork, games, ROMs, BIOS files, and firmware that you are legally allowed to use and redistribute.
LEGAL

cat > "$LB_CONFIG_DIR/includes.chroot/etc/lightdm/lightdm.conf.d/50-nexos-live-autologin.conf" <<LIGHTDM
[Seat:*]
autologin-user=$LIVE_USERNAME
autologin-user-timeout=0
user-session=xfce
greeter-session=lightdm-gtk-greeter
LIGHTDM

cat > "$LB_CONFIG_DIR/includes.chroot/etc/sudoers.d/90-nexos-live-user" <<'SUDOERS'
# NexOS live mode convenience. Installed systems will get stricter defaults later.
%sudo ALL=(ALL:ALL) NOPASSWD: ALL
SUDOERS
chmod 0440 "$LB_CONFIG_DIR/includes.chroot/etc/sudoers.d/90-nexos-live-user"

cat > "$LB_CONFIG_DIR/includes.chroot/usr/local/bin/nexos-info" <<'INFO'
#!/usr/bin/env bash
set -euo pipefail
if [[ -f /etc/nexos-release ]]; then
  cat /etc/nexos-release
else
  echo "NexOS release file not found."
fi
printf '\nUseful commands:\n'
printf '  nexos-info          Show this OS info\n'
printf '  sudo apt update     Refresh package lists\n'
printf '  xfce4-terminal      Open terminal\n'
INFO
chmod 0755 "$LB_CONFIG_DIR/includes.chroot/usr/local/bin/nexos-info"

cat > "$LB_CONFIG_DIR/includes.chroot/usr/share/applications/nexos-info.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Info
Comment=Show NexOS live build information
Exec=xfce4-terminal --hold --command=nexos-info
Icon=computer
Terminal=false
Categories=System;
DESKTOP

cat > "$LB_CONFIG_DIR/includes.chroot/etc/skel/Desktop/README-NexOS.txt" <<README
Welcome to NexOS live mode.

This is Part 2: the first bootable live desktop ISO.

Login user: $LIVE_USERNAME
Password: live mode should autologin. If asked, try an empty password first.

Open a terminal and run:
  nexos-info

Legal note:
NexOS must use original branding and legal open-source/user-provided software only.
README

cat > "$LB_CONFIG_DIR/includes.chroot/etc/skel/Desktop/NexOS-Info.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Info
Comment=Show NexOS live build information
Exec=xfce4-terminal --hold --command=nexos-info
Icon=computer
Terminal=false
Categories=System;
DESKTOP
chmod 0755 "$LB_CONFIG_DIR/includes.chroot/etc/skel/Desktop/NexOS-Info.desktop"

# Simple original SVG wallpaper. No copied Windows/Batocera/Microsoft assets.
cat > "$LB_CONFIG_DIR/includes.chroot/usr/share/backgrounds/nexos/nexos-origin.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#101827"/>
      <stop offset="0.5" stop-color="#18243a"/>
      <stop offset="1" stop-color="#0b101b"/>
    </linearGradient>
    <radialGradient id="glow" cx="50%" cy="45%" r="55%">
      <stop offset="0" stop-color="#34d399" stop-opacity="0.28"/>
      <stop offset="0.45" stop-color="#38bdf8" stop-opacity="0.12"/>
      <stop offset="1" stop-color="#000000" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="1920" height="1080" fill="url(#bg)"/>
  <rect width="1920" height="1080" fill="url(#glow)"/>
  <g fill="none" stroke="#38bdf8" stroke-opacity="0.18" stroke-width="2">
    <path d="M-80 780 C 340 560, 590 940, 1010 710 S 1600 550, 2020 700"/>
    <path d="M-80 860 C 360 640, 600 1000, 1050 790 S 1580 640, 2020 780"/>
  </g>
  <g transform="translate(760 405)">
    <rect x="0" y="0" width="400" height="230" rx="34" fill="#0f172a" fill-opacity="0.64" stroke="#7dd3fc" stroke-opacity="0.25"/>
    <text x="200" y="100" fill="#e5f8ff" font-family="DejaVu Sans, Arial, sans-serif" font-size="60" text-anchor="middle" font-weight="700">NexOS</text>
    <text x="200" y="150" fill="#9bd8ef" font-family="DejaVu Sans, Arial, sans-serif" font-size="22" text-anchor="middle">Origin Live Desktop</text>
  </g>
</svg>
SVG

cat > "$LB_CONFIG_DIR/hooks/normal/010-nexos-live-polish.hook.chroot" <<HOOK
#!/usr/bin/env bash
set -euo pipefail

# Generate requested locale when locales package is present.
if command -v locale-gen >/dev/null 2>&1; then
  sed -i 's/^# *$LIVE_LOCALE UTF-8/$LIVE_LOCALE UTF-8/' /etc/locale.gen || true
  locale-gen || true
  update-locale LANG=$LIVE_LOCALE || true
fi

# Keep sudoers permissions safe.
chmod 0440 /etc/sudoers.d/90-nexos-live-user || true

# Make live desktop launchers executable.
chmod 0755 /etc/skel/Desktop/*.desktop 2>/dev/null || true

# Set a basic wallpaper path for XFCE defaults where possible.
mkdir -p /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml
cat > /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitorVirtual1" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/nexos/nexos-origin.svg"/>
          <property name="image-style" type="int" value="5"/>
        </property>
      </property>
    </property>
  </property>
</channel>
XML

# Enable services in a way that does not hard-fail inside live-build chroots.
if command -v systemctl >/dev/null 2>&1; then
  systemctl enable NetworkManager.service 2>/dev/null || true
  systemctl enable lightdm.service 2>/dev/null || true
  systemctl enable qemu-guest-agent.service 2>/dev/null || true
  systemctl enable spice-vdagentd.service 2>/dev/null || true
fi
HOOK
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/010-nexos-live-polish.hook.chroot"

popd >/dev/null

success "live-build workspace initialized for Part 2."
log "Next checks: make part2-verify"
