#!/usr/bin/env bash
# Adds original NexOS SVG icons and fixes broken/missing desktop launcher icons.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

NEXOS_EDITION="${NEXOS_EDITION:-main}"
EDITION_LABEL="${EDITION_LABEL:-NexOS Main}"

ensure_dir "$LB_CONFIG_DIR/hooks/normal"

cat > "$LB_CONFIG_DIR/hooks/normal/110-nexos-icons-fix.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail

LIVE_USERNAME="__LIVE_USERNAME__"
home_dir="/home/$LIVE_USERNAME"
icon_dir="/usr/share/icons/hicolor/scalable/apps"
mkdir -p "$icon_dir" /usr/share/applications "$home_dir/Desktop"

make_icon() {
  local name="$1" glyph="$2" accent="$3"
  cat > "$icon_dir/$name.svg" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#0f172a"/>
      <stop offset="1" stop-color="#172554"/>
    </linearGradient>
  </defs>
  <rect x="10" y="10" width="108" height="108" rx="26" fill="url(#g)" stroke="$accent" stroke-width="4"/>
  <circle cx="98" cy="30" r="10" fill="$accent" opacity="0.9"/>
  <text x="64" y="78" text-anchor="middle" font-family="DejaVu Sans, Arial, sans-serif" font-size="44" font-weight="700" fill="#e8f7ff">$glyph</text>
</svg>
SVG
}

make_icon nexos-control-center "⚙" "#38bdf8"
make_icon nexos-install-center "⬇" "#22c55e"
make_icon nexos-dev-center "{}" "#a78bfa"
make_icon nexos-code-editor "<>" "#60a5fa"
make_icon nexos-help "?" "#facc15"
make_icon nexos-power "⏻" "#fb7185"
make_icon nexos-run "▶" "#34d399"
make_icon nexos-extractor "⛶" "#f59e0b"
make_icon nexos-system-report "i" "#7dd3fc"
make_icon nexos-maintenance "+" "#c084fc"
make_icon nexos-gpu "GPU" "#2dd4bf"
make_icon nexos-startup "N" "#38bdf8"

# Use original NexOS icons on our launchers and avoid missing icon placeholders.
set_icon() {
  local file="$1" icon="$2"
  [[ -f "$file" ]] || return 0
  if grep -q '^Icon=' "$file"; then
    sed -i "s|^Icon=.*|Icon=$icon|" "$file"
  else
    printf '\nIcon=%s\n' "$icon" >> "$file"
  fi
}

set_icon /usr/share/applications/nexos-control-center.desktop nexos-control-center
set_icon /usr/share/applications/nexos-install-center.desktop nexos-install-center
set_icon /usr/share/applications/nexos-installer.desktop nexos-install-center
set_icon /usr/share/applications/nexos-dev-center.desktop nexos-dev-center
set_icon /usr/share/applications/nexos-code-editor.desktop nexos-code-editor
set_icon /usr/share/applications/nexos-help.desktop nexos-help
set_icon /usr/share/applications/nexos-power.desktop nexos-power
set_icon /usr/share/applications/nexos-run.desktop nexos-run
set_icon /usr/share/applications/nexos-extractor.desktop nexos-extractor
set_icon /usr/share/applications/nexos-system-report.desktop nexos-system-report
set_icon /usr/share/applications/nexos-maintenance-center.desktop nexos-maintenance
set_icon /usr/share/applications/nexos-gpu-info.desktop nexos-gpu
set_icon /usr/share/applications/nexos-startup-center.desktop nexos-startup
set_icon /usr/share/applications/nexos-vm-display-help.desktop nexos-gpu

# Remove raw upstream installer shortcut from desktop; keep only NexOS Install Center.
rm -f "$home_dir/Desktop/calamares-install.desktop" "$home_dir/Desktop/Install System.desktop" 2>/dev/null || true

# Re-copy clean launchers after icon fixes.
copy_launcher() {
  local src="$1" dest="$2"
  [[ -f "$src" ]] || return 0
  cp -f "$src" "$home_dir/Desktop/$dest.desktop"
  chmod 0755 "$home_dir/Desktop/$dest.desktop" || true
}
copy_launcher /usr/share/applications/nexos-control-center.desktop "NexOS Control Center"
copy_launcher /usr/share/applications/nexos-install-center.desktop "NexOS Install Center"
copy_launcher /usr/share/applications/nexos-dev-center.desktop "NexOS Dev Center"
copy_launcher /usr/share/applications/nexos-help.desktop "NexOS Help"
copy_launcher /usr/share/applications/nexos-power.desktop "NexOS Power"
copy_launcher /usr/share/applications/nexos-startup-center.desktop "NexOS Startup Center"
copy_launcher /usr/share/applications/nexos-vm-display-help.desktop "NexOS VM Display Help"

# Hide any broken/extra .desktop files that cause launch errors.
mkdir -p "$home_dir/.local/share/nexos-hidden-desktop-launchers"
find "$home_dir/Desktop" -maxdepth 1 -type f -name '*.desktop' | while read -r file; do
  base="$(basename "$file")"
  case "$base" in
    "NexOS Control Center.desktop"|"NexOS Install Center.desktop"|"NexOS Dev Center.desktop"|"NexOS Help.desktop"|"NexOS Power.desktop"|"NexOS Startup Center.desktop"|"NexOS VM Display Help.desktop")
      chmod 0755 "$file" || true
      ;;
    *)
      mv -f "$file" "$home_dir/.local/share/nexos-hidden-desktop-launchers/$base" 2>/dev/null || rm -f "$file"
      ;;
  esac
done

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi

chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel
rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK

sed -i -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" "$LB_CONFIG_DIR/hooks/normal/110-nexos-icons-fix.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/110-nexos-icons-fix.hook.chroot"

success "Injected NexOS icon and launcher fixes for $NEXOS_EDITION."
