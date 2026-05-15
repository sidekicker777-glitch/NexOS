#!/usr/bin/env bash
# Verifies Part 2 files without requiring a full ISO build.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

log "Verifying Part 2 scripts and live-build seed files."

for script in "$PROJECT_ROOT"/scripts/*.sh "$PROJECT_ROOT"/scripts/lib/*.sh "$PROJECT_ROOT"/testing/*.sh; do
  [[ -f "$script" ]] || continue
  bash -n "$script"
  success "Syntax OK: ${script#$PROJECT_ROOT/}"
done

[[ -f "$PROJECT_ROOT/Makefile" ]] || fail "Missing Makefile"
[[ -f "$CONFIG_FILE" ]] || fail "Missing build-config/nexos.conf"
[[ -d "$LB_CONFIG_DIR" ]] || fail "Missing live-build/config. Run: make init"

required_files=(
  "$LB_CONFIG_DIR/package-lists/00-nexos-live-core.list.chroot"
  "$LB_CONFIG_DIR/package-lists/10-nexos-desktop-xfce.list.chroot"
  "$LB_CONFIG_DIR/package-lists/20-nexos-tools.list.chroot"
  "$LB_CONFIG_DIR/includes.chroot/etc/nexos-release"
  "$LB_CONFIG_DIR/includes.chroot/etc/lightdm/lightdm.conf.d/50-nexos-live-autologin.conf"
  "$LB_CONFIG_DIR/includes.chroot/usr/local/bin/nexos-info"
  "$LB_CONFIG_DIR/hooks/normal/010-nexos-live-polish.hook.chroot"
)

for file in "${required_files[@]}"; do
  [[ -f "$file" ]] || fail "Missing required Part 2 file: ${file#$PROJECT_ROOT/}"
  success "Found: ${file#$PROJECT_ROOT/}"
done

grep -q '^live-boot$' "$LB_CONFIG_DIR/package-lists/00-nexos-live-core.list.chroot" || fail "live-boot missing from live core packages"
grep -q '^live-config$' "$LB_CONFIG_DIR/package-lists/00-nexos-live-core.list.chroot" || fail "live-config missing from live core packages"
grep -q '^xfce4$' "$LB_CONFIG_DIR/package-lists/10-nexos-desktop-xfce.list.chroot" || fail "xfce4 missing from desktop packages"
grep -q '^lightdm$' "$LB_CONFIG_DIR/package-lists/10-nexos-desktop-xfce.list.chroot" || fail "lightdm missing from desktop packages"
grep -q '^build-essential$' "$LB_CONFIG_DIR/package-lists/20-nexos-tools.list.chroot" || fail "build-essential missing from tools packages"
[[ -x "$LB_CONFIG_DIR/hooks/normal/010-nexos-live-polish.hook.chroot" ]] || fail "Part 2 hook is not executable"
[[ -x "$LB_CONFIG_DIR/includes.chroot/usr/local/bin/nexos-info" ]] || fail "nexos-info is not executable"

if need_cmd lb; then
  log "live-build is installed. Running a config validation check."
  (cd "$LIVE_BUILD_DIR" && lb config --validate >/dev/null) || warn "lb config --validate reported an issue. Run make init, then make part2-verify again."
else
  warn "live-build is not installed in this environment, so lb config --validate was skipped."
fi

success "Part 2 verification passed."
