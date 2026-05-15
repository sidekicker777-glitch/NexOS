#!/usr/bin/env bash
# Verifies Part 1 foundation files without building the ISO.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

log "Verifying Part 1 foundation scripts and config."

for script in "$PROJECT_ROOT"/scripts/*.sh "$PROJECT_ROOT"/scripts/lib/*.sh; do
  [[ -f "$script" ]] || continue
  bash -n "$script"
  success "Syntax OK: ${script#$PROJECT_ROOT/}"
done

[[ -f "$PROJECT_ROOT/Makefile" ]] || fail "Missing Makefile"
[[ -f "$CONFIG_FILE" ]] || fail "Missing build-config/nexos.conf"
[[ -d "$PROJECT_ROOT/live-build/config" ]] || fail "Missing live-build/config. Run: make init"
[[ -f "$PROJECT_ROOT/live-build/config/includes.chroot/etc/nexos-release" ]] || fail "Missing /etc/nexos-release include. Run: make init"

success "Part 1 foundation verification passed."
