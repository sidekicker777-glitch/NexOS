#!/usr/bin/env bash
# Builds the first bootable NexOS live ISO using Debian live-build.

set -Eeuo pipefail
BUILD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$BUILD_SCRIPT_DIR/lib/common.sh"

require_cmd lb
require_cmd tee
require_cmd sha256sum
require_cmd find

ensure_dir "$ISO_DIR"
ensure_dir "$LOG_DIR"

log "Preparing fresh live-build configuration."
# Use bash explicitly so Windows/GitHub web uploads cannot break this by
# stripping Linux executable permissions from scripts. Use BUILD_SCRIPT_DIR
# because common.sh defines its own SCRIPT_DIR for the shared library folder.
bash "$BUILD_SCRIPT_DIR/02-init-live-build.sh"

log "Starting live-build. This downloads Debian packages and may take a while."
log "Target ISO: $ARTIFACT_ISO"

pushd "$LIVE_BUILD_DIR" >/dev/null

# Keep the build log even if live-build fails.
BUILD_LOG="$LOG_DIR/live-build-part2.log"
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  lb build 2>&1 | tee "$BUILD_LOG"
else
  sudo lb build 2>&1 | tee "$BUILD_LOG"
fi

popd >/dev/null

candidate="$(find "$LIVE_BUILD_DIR" -maxdepth 1 -type f \( -name '*.iso' -o -name '*.hybrid.iso' \) -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2- || true)"
if [[ -z "$candidate" || ! -f "$candidate" ]]; then
  fail "live-build finished but no ISO file was found in $LIVE_BUILD_DIR. Check $BUILD_LOG"
fi

cp -f "$candidate" "$ARTIFACT_ISO"
sha256sum "$ARTIFACT_ISO" > "$ARTIFACT_ISO.sha256"

success "ISO built: $ARTIFACT_ISO"
success "Checksum: $ARTIFACT_ISO.sha256"
log "Run: make validate-iso"
log "Optional quick boot test: make qemu-test"
