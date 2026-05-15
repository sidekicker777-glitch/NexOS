#!/usr/bin/env bash
# Injects NexOS OS identity, boot branding, startup center, and VM display notes.
# Goal: make the ISO feel like NexOS instead of Debian during boot/login/live desktop.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

NEXOS_EDITION="${NEXOS_EDITION:-main}"
EDITION_LABEL="${EDITION_LABEL:-NexOS Main}"

ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"

cat > "$LB_CONFIG_DIR/package-lists/51-nexos-branding-boot.list.chroot" <<'PKGS'
# NexOS boot/identity polish.
plymouth
plymouth-themes
lsb-release
neofetch
fastfetch
mesa-utils
firmware-linux-free
firmware-misc-nonfree
PKGS

cat > "$LB_CONFIG_DIR/hooks/normal/100-nexos-branding-boot.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

LIVE_USERNAME="__LIVE_USERNAME__"
NEXOS_EDITION="__NEXOS_EDITION__"
EDITION_LABEL="__EDITION_LABEL__"
home_dir="/home/$LIVE_USERNAME"

install_if_available() {
  local pkg="$1"
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    apt-get install -y --no-install-recommends "$pkg" || true
  fi
}

apt-get update || true
for pkg in plymouth plymouth-themes lsb-release neofetch fastfetch mesa-utils firmware-linux-free firmware-misc-nonfree; do
  install_if_available "$pkg"
done

mkdir -p \
  /usr/local/bin \
  /usr/share/applications \
  /usr/share/nexos \
  /usr/share/plymouth/themes/nexos \
  /etc/default/grub.d \
  /etc/lightdm/lightdm-gtk-greeter.conf.d \
  "$home_dir/Desktop" \
  "$home_dir/.config/autostart"

cat > /etc/hostname <<'EOF'
nexos-live
EOF

cat > /etc/hosts <<'EOF'
127.0.0.1 localhost
127.0.1.1 nexos-live

::1 localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

cat > /etc/os-release <<EOF
PRETTY_NAME="$EDITION_LABEL"
NAME="NexOS"
VERSION="Origin Live"
VERSION_ID="0.1"
VERSION_CODENAME="origin"
ID=nexos
ID_LIKE=debian
HOME_URL="https://github.com/sidekicker777-glitch/NexOS"
SUPPORT_URL="https://github.com/sidekicker777-glitch/NexOS/issues"
BUG_REPORT_URL="https://github.com/sidekicker777-glitch/NexOS/issues"
EOF

cat > /etc/lsb-release <<EOF
DISTRIB_ID=NexOS
DISTRIB_RELEASE=0.1
DISTRIB_CODENAME=origin
DISTRIB_DESCRIPTION="$EDITION_LABEL"
EOF

cat > /etc/issue <<EOF
$EDITION_LABEL \\n \\l

EOF
cat > /etc/issue.net <<EOF
$EDITION_LABEL
EOF
cat > /etc/motd <<EOF
Welcome to $EDITION_LABEL.

Useful commands:
  nexos-startup-center
  nexos-control-center
  nexos-vm-display-help
  nexos-gpu-info
EOF

# Plymouth text theme. This is intentionally simple and original.
cat > /usr/share/plymouth/themes/nexos/nexos.plymouth <<'EOF'
[Plymouth Theme]
Name=NexOS
Description=NexOS boot splash
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/nexos
ScriptFile=/usr/share/plymouth/themes/nexos/nexos.script
EOF

cat > /usr/share/plymouth/themes/nexos/nexos.script <<'EOF'
Window.SetBackgroundTopColor(0.02, 0.05, 0.09);
Window.SetBackgroundBottomColor(0.00, 0.00, 0.00);

screen_width = Window.GetWidth();
screen_height = Window.GetHeight();

message = Image.Text("NexOS", 1, 1, 1);
subtitle = Image.Text("Starting live desktop...", 0.45, 0.82, 1);
msg_sprite = Sprite(message);
sub_sprite = Sprite(subtitle);
msg_sprite.SetX(screen_width / 2 - message.GetWidth() / 2);
msg_sprite.SetY(screen_height / 2 - 60);
sub_sprite.SetX(screen_width / 2 - subtitle.GetWidth() / 2);
sub_sprite.SetY(screen_height / 2 + 20);

fun refresh_callback() {
  progress = Plymouth.GetBootProgress();
}
Plymouth.SetRefreshFunction(refresh_callback);
EOF

if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  plymouth-set-default-theme nexos || true
  update-initramfs -u || true
fi

cat > /etc/default/grub.d/99-nexos-branding.cfg <<'EOF'
GRUB_DISTRIBUTOR="NexOS"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash vt.global_cursor_default=0"
EOF

cat > /etc/lightdm/lightdm-gtk-greeter.conf.d/50-nexos-greeter.conf <<EOF
[greeter]
background=/usr/share/backgrounds/nexos/nexos-default.png
theme-name=Arc-Dark
icon-theme-name=Papirus-Dark
font-name=Noto Sans 11
indicators=~host;~spacer;~clock;~spacer;~session;~power
EOF

cat > /usr/local/bin/nexos-gpu-info <<'GPUINFO'
#!/usr/bin/env bash
set -euo pipefail
report="/tmp/nexos-gpu-info-$(date +%s).txt"
{
  echo "NexOS GPU / Display Info"
  echo "========================"
  date
  echo
  echo "Important VM note:"
  echo "If NexOS is running inside VirtualBox, it normally sees a VirtualBox virtual graphics adapter, not your real NVIDIA/AMD/Intel GPU."
  echo "Real GPU detection inside a VM requires GPU passthrough, which is advanced and usually not available in normal VirtualBox setups."
  echo
  echo "PCI graphics devices:"
  lspci -nn | grep -Ei 'vga|3d|display' || true
  echo
  echo "Kernel modules:"
  lsmod | grep -Ei 'vbox|vmwgfx|nouveau|amdgpu|radeon|i915|nvidia' || true
  echo
  echo "OpenGL renderer:"
  if command -v glxinfo >/dev/null 2>&1; then glxinfo -B 2>/dev/null || true; else echo "glxinfo not installed"; fi
  echo
  echo "xrandr:"
  xrandr --query 2>/dev/null || true
} > "$report" 2>&1
if command -v mousepad >/dev/null 2>&1; then mousepad "$report" >/dev/null 2>&1 & else xdg-open "$report" >/dev/null 2>&1 & fi
GPUINFO
chmod 0755 /usr/local/bin/nexos-gpu-info

cat > /usr/local/bin/nexos-vm-display-help <<'VMHELP'
#!/usr/bin/env bash
set -euo pipefail
cat > /tmp/nexos-vm-display-help.txt <<'TXT'
NexOS VirtualBox Display Help
=============================

Why the GPU looks wrong:
- In VirtualBox, the guest OS usually sees a virtual GPU, not your real graphics card.
- This is normal. Your real GPU will not show unless you use advanced GPU passthrough.

Recommended VirtualBox settings:
1. Power off the VM.
2. Open Settings > Display.
3. Set Video Memory to 128 MB.
4. Enable 3D Acceleration.
5. Try Graphics Controller: VMSVGA first.
6. If you see vmwgfx errors or black screens, try VBoxSVGA.
7. Boot NexOS again.
8. In the VM menu: View > Auto-resize Guest Display.

Inside NexOS:
- Run: nexos-display-fix
- Run: nexos-gpu-info

Black screen delay:
- A short black screen can happen while Xorg, LightDM, and the live desktop start.
- The build now includes a NexOS splash/startup center to make this less ugly.
TXT
if command -v mousepad >/dev/null 2>&1; then mousepad /tmp/nexos-vm-display-help.txt >/dev/null 2>&1 & else xdg-open /tmp/nexos-vm-display-help.txt >/dev/null 2>&1 & fi
VMHELP
chmod 0755 /usr/local/bin/nexos-vm-display-help

cat > /usr/local/bin/nexos-startup-center <<'STARTUP'
#!/usr/bin/env bash
set -euo pipefail
choice="$(zenity --list --title="Welcome to NexOS" --width=820 --height=520 --print-column=1 --column="Open" --column="Description" \
  "Control Center" "Settings, tools, system helpers" \
  "Install Center" "Install NexOS in a VM or disk" \
  "Dev Center" "Create code projects and check compilers" \
  "Display Help" "Fix VirtualBox size/GPU display issues" \
  "GPU Info" "Show what graphics adapter NexOS sees" \
  "App Map" "See open-source foundations wrapped by NexOS" \
  "Close" "Close this welcome screen" || true)"
[[ -n "$choice" ]] || exit 0
case "$choice" in
  "Control Center") nexos-control-center >/dev/null 2>&1 & ;;
  "Install Center") nexos-install-center >/dev/null 2>&1 & ;;
  "Dev Center") nexos-dev-center >/dev/null 2>&1 & ;;
  "Display Help") nexos-vm-display-help >/dev/null 2>&1 & ;;
  "GPU Info") nexos-gpu-info >/dev/null 2>&1 & ;;
  "App Map") nexos-app-map >/dev/null 2>&1 & ;;
  Close) exit 0 ;;
esac
STARTUP
chmod 0755 /usr/local/bin/nexos-startup-center

cat > "$home_dir/.config/autostart/nexos-startup-center.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Startup Center
Exec=sh -c 'sleep 3; nexos-startup-center'
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP

make_desktop() {
  local path="$1" name="$2" comment="$3" exec_cmd="$4" icon="$5" cats="$6"
  cat > "$path" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Comment=$comment
Exec=$exec_cmd
Icon=$icon
Terminal=false
Categories=$cats
DESKTOP
}
make_desktop /usr/share/applications/nexos-startup-center.desktop "NexOS Startup Center" "Open the NexOS welcome/startup screen" "nexos-startup-center" "nexos-startup" "System;"
make_desktop /usr/share/applications/nexos-gpu-info.desktop "NexOS GPU Info" "Show GPU and display information" "nexos-gpu-info" "nexos-gpu" "System;"
make_desktop /usr/share/applications/nexos-vm-display-help.desktop "NexOS VM Display Help" "VirtualBox display and GPU help" "nexos-vm-display-help" "nexos-gpu" "System;"

cp -f /usr/share/applications/nexos-startup-center.desktop "$home_dir/Desktop/NexOS Startup Center.desktop" || true
cp -f /usr/share/applications/nexos-vm-display-help.desktop "$home_dir/Desktop/NexOS VM Display Help.desktop" || true
chmod 0755 "$home_dir/Desktop/NexOS Startup Center.desktop" "$home_dir/Desktop/NexOS VM Display Help.desktop" 2>/dev/null || true

cat >> /usr/share/nexos/app-map.txt <<'APPMAP_APPEND'

Branding and boot identity:
- NexOS Startup Center: the first visible welcome/start screen after login.
- NexOS GPU Info: shows virtual/real display adapters and OpenGL renderer information.
- NexOS VM Display Help: explains VirtualBox display controller and GPU limits.
- NexOS Plymouth Theme: simple original NexOS boot splash.
- NexOS OS identity files: os-release, issue, motd, hostname, and greeter branding.
APPMAP_APPEND

chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel
rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK

sed -i \
  -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" \
  -e "s/__NEXOS_EDITION__/$NEXOS_EDITION/g" \
  -e "s/__EDITION_LABEL__/$EDITION_LABEL/g" \
  "$LB_CONFIG_DIR/hooks/normal/100-nexos-branding-boot.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/100-nexos-branding-boot.hook.chroot"

cat > "$LB_CONFIG_DIR/hooks/normal/900-nexos-bootloader-branding.hook.binary" <<'BINARYHOOK'
#!/usr/bin/env bash
set -euo pipefail

find . -type f \( -name '*.cfg' -o -name '*.txt' -o -name '*.conf' \) 2>/dev/null | while read -r file; do
  sed -i \
    -e 's/Debian GNU\/Linux 13 (trixie)/NexOS Origin/g' \
    -e 's/Debian GNU\/Linux/NexOS/g' \
    -e 's/Debian Live/NexOS Live/g' \
    -e 's/Live system/NexOS Live Desktop/g' \
    -e 's/Live system (fail-safe mode)/NexOS Live Desktop (safe graphics)/g' \
    -e 's/amd64/NexOS amd64/g' \
    "$file" || true
done
BINARYHOOK
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/900-nexos-bootloader-branding.hook.binary"

success "Injected NexOS branding/boot identity for $NEXOS_EDITION."
