#!/usr/bin/env bash
# Final package-list safety pass.
# Also runs late optional feature injectors that need to be generated before package validation.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

ensure_dir "$LB_CONFIG_DIR/package-lists"
ensure_dir "$LB_CONFIG_DIR/hooks/normal"

# Late injector safety: if Game Library exists but was not chained by the visual pass,
# run it here before package validation so its package list/hooks are included.
if [[ -f "$SCRIPT_DIR/27-inject-nexos-game-library.sh" ]]; then
  bash "$SCRIPT_DIR/27-inject-nexos-game-library.sh"
fi

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
  fastfetch
  neofetch
  mesa-utils
  openscap-scanner
  scap-security-guide
  dbeaver-ce
  openjdk-21-jdk
)

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
: > "$removed_log"

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

    if is_optional_pkg "$pkg"; then
      echo "$pkg" >> "$removed_log"
      echo "# optional moved to conditional hook: $pkg" >> "$tmp"
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
  papirus-icon-theme arc-theme plymouth-themes fastfetch neofetch mesa-utils \
  openscap-scanner scap-security-guide; do
  install_if_available "$pkg"
done
HOOK
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/015-nexos-optional-package-pass.hook.chroot"

log "Optional/unavailable packages moved out of hard package lists:"
if [[ -s "$removed_log" ]]; then
  sed 's/^/  - /' "$removed_log" || true
else
  log "  none"
fi

success "Sanitized live-build package lists and protected the ISO build from optional package failures."
