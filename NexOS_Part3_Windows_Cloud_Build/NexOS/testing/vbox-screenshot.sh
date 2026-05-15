#!/usr/bin/env bash
# Captures a PNG screenshot from the running VirtualBox VM.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=vbox-lib.sh
source "$SCRIPT_DIR/vbox-lib.sh"

vbox_require
vbox_exists || fail "VM '$VBOX_VM_NAME' does not exist. Run: make vbox-create"
vbox_running || fail "VM '$VBOX_VM_NAME' is not running. Run: make vbox-start"
ensure_dir "$VBOX_SCREENSHOT_DIR"

ts="$(date +%Y%m%d-%H%M%S)"
out="$VBOX_SCREENSHOT_DIR/${VBOX_VM_NAME}-${ts}.png"

VBoxManage controlvm "$VBOX_VM_NAME" screenshotpng "$out"
success "Screenshot saved: $out"
