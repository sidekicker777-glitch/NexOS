#!/usr/bin/env bash
# Final package-list safety pass.
# live-build fails hard if any package in package-lists/*.list.chroot is missing.
# Optional polish/VM/installer packages must be installed conditionally in hooks instead.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

ensure_dir "$LB_CONFIG_DIR/package-lists"

# Packages here are useful when available, but they are not guaranteed in every
# Debian Trixie runner/archive-area combination. They are installed with
# install_if_available inside hooks, so remove them from hard package lists.
OPTIONAL_UNSAFE_PACKAGES=(
  calamares
  calamares-settings-debian
  virtualbox-guest-x11
  virtualbox-guest-utils
  xserver-xorg-video-vmware
  xserver-xorg-video-qxl
  firmware-misc-nonfree
  xfce4-appmenu-plugin
  openscap-scanner
  scap-security-guide
  dbeaver-ce
  openjdk-21-jdk
)

for list in "$LB_CONFIG_DIR"/package-lists/*.list.chroot; do
  [[ -f "$list" ]] || continue
  for pkg in "${OPTIONAL_UNSAFE_PACKAGES[@]}"; do
    sed -i "/^${pkg}$/d" "$list"
  done
  # Remove duplicate blank lines so the generated lists stay readable.
  awk 'NF || !blank {print} {blank=!NF}' "$list" > "$list.tmp"
  mv "$list.tmp" "$list"
done

# Conditional hook for packages removed from hard lists.
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
  xfce4-appmenu-plugin \
  openscap-scanner scap-security-guide; do
  install_if_available "$pkg"
done
HOOK
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/015-nexos-optional-package-pass.hook.chroot"

success "Sanitized live-build package lists and moved risky optional packages to conditional install hook."
