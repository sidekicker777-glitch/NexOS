#!/usr/bin/env bash
# Reattaches the current NexOS ISO to the existing VirtualBox VM.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=vbox-lib.sh
source "$SCRIPT_DIR/vbox-lib.sh"

vbox_require
vbox_iso_ready
vbox_exists || fail "VM '$VBOX_VM_NAME' does not exist. Run: make vbox-create"
vbox_poweroff_if_running

log "Attaching ISO to $VBOX_VM_NAME: $ARTIFACT_ISO"
VBoxManage storageattach "$VBOX_VM_NAME" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium "$ARTIFACT_ISO"
VBoxManage modifyvm "$VBOX_VM_NAME" --boot1 dvd --boot2 disk --boot3 none --boot4 none
success "ISO attached. Start the VM with: make vbox-start"
