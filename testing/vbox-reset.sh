#!/usr/bin/env bash
# Resets the NexOS VirtualBox VM back to the clean snapshot.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=vbox-lib.sh
source "$SCRIPT_DIR/vbox-lib.sh"

vbox_require
vbox_exists || fail "VM '$VBOX_VM_NAME' does not exist. Run: make vbox-create"
vbox_poweroff_if_running

snapshot="${VBOX_SNAPSHOT_NAME:-Fresh-Live-ISO-Test}"
log "Restoring snapshot: $snapshot"
VBoxManage snapshot "$VBOX_VM_NAME" restore "$snapshot"
success "VM reset to snapshot: $snapshot"
