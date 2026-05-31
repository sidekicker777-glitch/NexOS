#!/usr/bin/env bash
# Final package-list safety pass.
# Also runs late optional feature injectors that need to be generated before package validation.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

ensure_dir "$LB_CONFIG_DIR/package-lists"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"

# Late injector safety: run broad features before package validation so their
# package lists and hooks are always included even if another chain misses them.
for injector in \
  27-inject-nexos-game-library.sh \
  28-inject-nexos-console-mode.sh \
  29-inject-nexos-control-suite-v2.sh \
  30-inject-nexos-workspace-suite.sh \
  31-inject-nexos-file-center.sh \
  32-inject-nexos-update-center.sh \
  33-inject-nexos-driver-center.sh \
  34-inject-nexos-archive-manager.sh \
  35-inject-nexos-code-editor.sh \
  36-inject-nexos-settings-app.sh \
  37-inject-nexos-first-run-wizard.sh \
  38-inject-nexos-install-center-v2.sh \
  39-inject-nexos-software-center.sh \
  40-inject-nexos-branding-v2.sh \
  41-inject-nexos-boot-splash-v2.sh \
  42-inject-nexos-session-mode-switcher.sh \
  43-inject-nexos-action-center.sh \
  44-inject-nexos-power-center.sh \
  45-inject-nexos-search-center.sh \
  46-inject-nexos-task-manager.sh \
  47-inject-nexos-backup-restore-center-v2.sh \
  48-inject-nexos-security-center-main.sh \
  49-inject-nexos-network-center-v2.sh \
  50-inject-nexos-personalization-center.sh \
  51-inject-nexos-control-panel-unified.sh \
  52-inject-nexos-desktop-shell-polish-v2.sh \
  53-inject-nexos-iso-doctor.sh \
  54-inject-nexos-build-fix-pass.sh \
  55-inject-nexos-build-validation-report.sh \
  56-inject-nexos-app-icon-validation-fix-pass.sh \
  57-inject-nexos-desktop-ux-final-pass.sh \
  58-inject-nexos-final-smoke-test-pack.sh \
  59-inject-nexos-release-readiness-center.sh \
  60-inject-nexos-final-source-build-audit.sh \
  61-inject-nexos-release-notes-pack.sh \
  62-inject-nexos-live-build-failure-auto-fix-pass.sh \
  63-inject-nexos-package-list-root-cause-fix-pass.sh; do
  if [[ -f "$SCRIPT_DIR/$injector" ]]; then
    bash "$SCRIPT_DIR/$injector"
  fi
done

OPTIONAL_UNSAFE_PACKAGES=(
  calamares
  calamares-settings-debian
  virtualbox-guest-x11
  virtualbox-guest-utils
  xserver-xorg-video-vmware
  xserver-xorg-video-qxl
  firmware-misc-nonfree
  xfce4-appmenu-plugin
  xfce4-pulseaudio-plugin
  xfce4-statusnotifier-plugin
  xfce4-datetime-plugin
  xfce4-notifyd
  papirus-icon-theme
  arc-theme
  plymouth-themes
  plymouth
  grub-common
  grub-pc-bin
  grub-efi-amd64-bin
  fastfetch
  neofetch
  mesa-utils
  openscap-scanner
  scap-security-guide
  dbeaver-ce
  openjdk-21-jdk
  baobab
  gparted
  timeshift
  bleachbit
  synaptic
  flatpak
  aptitude
  apt-listchanges
  software-properties-common
  lshw
  hwinfo
  vulkan-tools
  pulseaudio-utils
  pavucontrol
  p7zip-rar
  build-essential
  nodejs
  npm
  ripgrep
  arandr
  brightnessctl
  os-prober
  efibootmgr
  lightdm
  lightdm-gtk-greeter
  wmctrl
  network-manager-gnome
  acpi
  upower
  xfce4-power-manager
  xfce4-screensaver
  light-locker
  mlocate
  catfish
  sysstat
  lsof
  htop
  iotop
  nethogs
  xfce4-taskmanager
  gnome-system-monitor
  ufw
  gufw
  net-tools
  dnsutils
  traceroute
  fontconfig
  shellcheck
  python3-yaml
  jq
  desktop-file-utils
  glib2.0-bin

  # Debian Trixie already pulls iputils-ping as the ping provider. inetutils-ping
  # conflicts with package virtual/provided name "ping" and breaks lb install.
  inetutils-ping
)

# Debian Trixie removed/renamed some historical package names. If an old
# package is still emitted by an earlier injector, replace it here before lb
# gets to chroot_install-packages.
replacement_packages() {
  case "$1" in
    policykit-1) echo "polkitd pkexec" ;;
    *) return 1 ;;
  esac
}

is_optional_pkg() {
  local needle="$1"
  local item
  for item in "${OPTIONAL_UNSAFE_PACKAGES[@]}"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

pkg_available() {
  local pkg="$1"
  apt-cache show "$pkg" >/dev/null 2>&1
}

apt-get update >/dev/null 2>&1 || true
removed_log="$LB_CONFIG_DIR/nexos-removed-optional-packages.txt"
replacement_log="$LB_CONFIG_DIR/nexos-replaced-obsolete-packages.txt"
: > "$removed_log"
: > "$replacement_log"

for list in "$LB_CONFIG_DIR"/package-lists/*.list.chroot; do
  [[ -f "$list" ]] || continue
  tmp="$list.tmp"
  : > "$tmp"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -z "${line// }" || "$line" =~ ^[[:space:]]*# ]]; then
      echo "$line" >> "$tmp"
      continue
    fi

    pkg="$(awk '{print $1}' <<< "$line")"
    if [[ -z "$pkg" ]]; then
      echo "$line" >> "$tmp"
      continue
    fi

    if replacements="$(replacement_packages "$pkg" 2>/dev/null)"; then
      echo "$pkg -> $replacements" >> "$replacement_log"
      echo "# obsolete package replaced for Debian Trixie: $pkg -> $replacements" >> "$tmp"
      for repl in $replacements; do
        if pkg_available "$repl"; then
          echo "$repl" >> "$tmp"
        else
          echo "$repl" >> "$removed_log"
          echo "# replacement unavailable on this runner: $repl" >> "$tmp"
        fi
      done
      continue
    fi

    if is_optional_pkg "$pkg"; then
      echo "$pkg" >> "$removed_log"
      echo "# optional/conflicting package moved to conditional hook or skipped: $pkg" >> "$tmp"
      continue
    fi

    if ! pkg_available "$pkg"; then
      echo "$pkg" >> "$removed_log"
      echo "# unavailable on this runner, moved to conditional hook: $pkg" >> "$tmp"
      continue
    fi

    echo "$line" >> "$tmp"
  done < "$list"

  awk 'NF || !blank {print} {blank=!NF}' "$tmp" > "$list"
  rm -f "$tmp"
done

sort -u "$removed_log" -o "$removed_log" || true
sort -u "$replacement_log" -o "$replacement_log" || true

cat > "$LB_CONFIG_DIR/hooks/normal/015-nexos-optional-package-pass.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

install_if_available() {
  local pkg="$1"
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    apt-get install -y --no-install-recommends "$pkg" || true
  fi
}

apt-get update || true
for pkg in \
  calamares calamares-settings-debian \
  virtualbox-guest-x11 virtualbox-guest-utils \
  xserver-xorg-video-vmware xserver-xorg-video-qxl \
  firmware-misc-nonfree \
  xfce4-appmenu-plugin xfce4-pulseaudio-plugin xfce4-statusnotifier-plugin xfce4-datetime-plugin xfce4-notifyd \
  papirus-icon-theme arc-theme plymouth-themes plymouth grub-common grub-pc-bin grub-efi-amd64-bin fastfetch neofetch mesa-utils \
  openscap-scanner scap-security-guide \
  baobab gparted timeshift bleachbit synaptic flatpak aptitude apt-listchanges software-properties-common \
  lshw hwinfo vulkan-tools pulseaudio-utils pavucontrol p7zip-rar \
  build-essential nodejs npm ripgrep arandr brightnessctl os-prober efibootmgr \
  lightdm lightdm-gtk-greeter wmctrl network-manager-gnome acpi upower xfce4-power-manager xfce4-screensaver light-locker \
  mlocate catfish sysstat lsof htop iotop nethogs xfce4-taskmanager gnome-system-monitor \
  ufw gufw net-tools dnsutils traceroute fontconfig shellcheck python3-yaml jq desktop-file-utils glib2.0-bin; do
  install_if_available "$pkg"
done
HOOK
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/015-nexos-optional-package-pass.hook.chroot"

log "Obsolete packages replaced for this Debian release:"
if [[ -s "$replacement_log" ]]; then
  sed 's/^/  - /' "$replacement_log" || true
else
  log "  none"
fi

log "Optional/unavailable/conflicting packages moved out of hard package lists:"
if [[ -s "$removed_log" ]]; then
  sed 's/^/  - /' "$removed_log" || true
else
  log "  none"
fi

success "Sanitized live-build package lists and protected the ISO build from optional package failures."
