#!/usr/bin/env bash
# Stops the NexOS VirtualBox VM.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=vbox-lib.sh
source "$SCRIPT_DIR/vbox-lib.sh"

mode="acpipowerbutton"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --poweroff) mode="poweroff" ;;
    --acpi) mode="acpipowerbutton" ;;
    -h|--help)
      echo "Usage: $0 [--acpi|--poweroff]"
      exit 0
      ;;
    *) fail "Unknown option: $1" ;;
  esac
  shift
done

vbox_require
vbox_exists || fail "VM '$VBOX_VM_NAME' does not exist."

if ! vbox_running; then
  warn "VM is not running: $VBOX_VM_NAME"
  exit 0
fi

if [[ "$mode" == "poweroff" ]]; then
  warn "Hard poweroff requested."
  VBoxManage controlvm "$VBOX_VM_NAME" poweroff
else
  log "Sending ACPI power button to allow a clean shutdown."
  VBoxManage controlvm "$VBOX_VM_NAME" acpipowerbutton
fi

success "Stop signal sent. Current state: $(vbox_power_state)"
