#!/usr/bin/env bash
# Cleans generated build files safely.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

case "${1:-light}" in
  light)
    log "Running light clean."
    if [[ -d "$LIVE_BUILD_DIR" ]] && need_cmd lb; then
      (cd "$LIVE_BUILD_DIR" && sudo_cmd lb clean) || true
    fi
    ;;
  full)
    log "Running full clean."
    rm -rf "$PROJECT_ROOT/build" "$PROJECT_ROOT/iso" "$PROJECT_ROOT/workspace"
    if [[ -d "$LIVE_BUILD_DIR" ]] && need_cmd lb; then
      (cd "$LIVE_BUILD_DIR" && sudo_cmd lb clean --purge) || true
    fi
    ;;
  *)
    fail "Usage: $0 [light|full]"
    ;;
esac

success "Clean complete."
