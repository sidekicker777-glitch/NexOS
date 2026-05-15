#!/usr/bin/env bash
# Deletes the NexOS VirtualBox VM and its generated test disk.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=vbox-lib.sh
source "$SCRIPT_DIR/vbox-lib.sh"

vbox_require

if ! vbox_exists; then
  warn "VM does not exist: $VBOX_VM_NAME"
  exit 0
fi

vbox_poweroff_if_running
warn "Deleting VM and attached media: $VBOX_VM_NAME"
VBoxManage unregistervm "$VBOX_VM_NAME" --delete
rm -f "$SCRIPT_DIR/${VBOX_VM_NAME}.vdi"
success "Deleted VM: $VBOX_VM_NAME"
