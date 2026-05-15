#!/usr/bin/env bash
# Validates the generated NexOS ISO artifact.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

NEXOS_EDITION="${NEXOS_EDITION:-main}"
case "$NEXOS_EDITION" in
  main)
    TARGET_ISO="$ARTIFACT_ISO"
    ;;
  tools)
    TARGET_ISO="$ISO_DIR/${ISO_IMAGE_NAME%.iso}-tools.iso"
    ;;
  creator)
    TARGET_ISO="$ISO_DIR/${ISO_IMAGE_NAME%.iso}-creator.iso"
    ;;
  security)
    TARGET_ISO="$ISO_DIR/${ISO_IMAGE_NAME%.iso}-security.iso"
    ;;
  *)
    fail "Invalid NEXOS_EDITION='$NEXOS_EDITION'. Use: main, tools, creator, or security"
    ;;
esac

[[ -f "$TARGET_ISO" ]] || fail "Missing ISO: $TARGET_ISO. Build it first with: NEXOS_EDITION=$NEXOS_EDITION make iso"
[[ -f "$TARGET_ISO.sha256" ]] || fail "Missing checksum: $TARGET_ISO.sha256"

size_bytes="$(stat -c '%s' "$TARGET_ISO")"
if (( size_bytes < 200000000 )); then
  fail "ISO is unexpectedly small (${size_bytes} bytes). Build may be incomplete."
fi

log "Validating $NEXOS_EDITION ISO checksum."
(cd "$ISO_DIR" && sha256sum -c "$(basename "$TARGET_ISO.sha256")")

if need_cmd file; then
  log "ISO file type:"
  file "$TARGET_ISO"
fi

if need_cmd xorriso; then
  log "Checking ISO boot catalog with xorriso."
  xorriso -indev "$TARGET_ISO" -report_el_torito plain >/tmp/nexos-el-torito.txt 2>/tmp/nexos-el-torito.err || {
    cat /tmp/nexos-el-torito.err >&2 || true
    fail "xorriso could not inspect the ISO boot catalog."
  }
  if grep -Eiq 'El Torito|EFI|boot' /tmp/nexos-el-torito.txt; then
    success "Boot catalog detected."
  else
    warn "xorriso ran, but no obvious boot catalog text was found. Inspect /tmp/nexos-el-torito.txt"
  fi
else
  warn "xorriso not installed; skipping boot catalog inspection."
fi

success "ISO validation complete for $NEXOS_EDITION edition."
