#!/usr/bin/env bash
# Prints the status of the NexOS VirtualBox VM and testing artifacts.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=vbox-lib.sh
source "$SCRIPT_DIR/vbox-lib.sh"

vbox_require
ensure_dir "$VBOX_ARTIFACT_DIR"

if vbox_exists; then
  vbox_print_summary
  echo
  VBoxManage showvminfo "$VBOX_VM_NAME" --machinereadable | grep -E '^(name|ostype|VMState|memory|cpus|firmware|graphicscontroller|vram|nic1|audio|clipboard|draganddrop|CfgFile)=' || true
else
  warn "VM does not exist yet: $VBOX_VM_NAME"
  log "Create it with: make vbox-create"
fi
