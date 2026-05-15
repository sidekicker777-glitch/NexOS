#!/usr/bin/env bash
# Starts the NexOS VirtualBox VM.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=vbox-lib.sh
source "$SCRIPT_DIR/vbox-lib.sh"

mode="${VBOX_START_MODE:-gui}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --headless) mode="headless" ;;
    --gui) mode="gui" ;;
    -h|--help)
      echo "Usage: $0 [--gui|--headless]"
      exit 0
      ;;
    *) fail "Unknown option: $1" ;;
  esac
  shift
done

vbox_require
vbox_exists || fail "VM '$VBOX_VM_NAME' does not exist. Run: make vbox-create"

if vbox_running; then
  warn "VM is already running: $VBOX_VM_NAME"
  exit 0
fi

log "Starting $VBOX_VM_NAME using mode: $mode"
VBoxManage startvm "$VBOX_VM_NAME" --type "$mode"
success "VM started. Use make vbox-screenshot and make vbox-logs during testing."
