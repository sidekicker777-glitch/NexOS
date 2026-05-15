#!/usr/bin/env bash
# Shared VirtualBox helpers for NexOS test scripts.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/lib/common.sh
source "$SCRIPT_DIR/../scripts/lib/common.sh"

VBOX_ARTIFACT_DIR="$PROJECT_ROOT/${VBOX_LOG_DIR:-build/virtualbox}"
VBOX_SCREENSHOT_DIR="$VBOX_ARTIFACT_DIR/screenshots"
VBOX_INFO_DIR="$VBOX_ARTIFACT_DIR/info"
VBOX_COPIED_LOG_DIR="$VBOX_ARTIFACT_DIR/vbox-logs"

vbox_require() {
  require_cmd VBoxManage
}

vbox_exists() {
  VBoxManage list vms | grep -Fq "\"$VBOX_VM_NAME\""
}

vbox_running() {
  VBoxManage list runningvms | grep -Fq "\"$VBOX_VM_NAME\""
}

vbox_power_state() {
  if ! vbox_exists; then
    echo "missing"
    return 0
  fi
  VBoxManage showvminfo "$VBOX_VM_NAME" --machinereadable 2>/dev/null \
    | awk -F= '/^VMState=/ {gsub(/\"/, "", $2); print $2; found=1} END {if (!found) print "unknown"}'
}

vbox_vm_folder() {
  VBoxManage showvminfo "$VBOX_VM_NAME" --machinereadable 2>/dev/null \
    | awk -F= '/^CfgFile=/ {gsub(/\"/, "", $2); sub(/\/[^\/]+$/, "", $2); print $2; found=1} END {if (!found) exit 1}'
}

vbox_wait_for_poweroff() {
  local timeout_seconds="${1:-60}"
  local waited=0
  while vbox_running; do
    if (( waited >= timeout_seconds )); then
      return 1
    fi
    sleep 2
    waited=$((waited + 2))
  done
}

vbox_poweroff_if_running() {
  if vbox_running; then
    warn "VM is running. Powering it off: $VBOX_VM_NAME"
    VBoxManage controlvm "$VBOX_VM_NAME" poweroff >/dev/null || true
    vbox_wait_for_poweroff 60 || fail "Timed out waiting for VM to power off."
  fi
}

vbox_iso_ready() {
  [[ -f "$ARTIFACT_ISO" ]] || fail "Missing ISO: $ARTIFACT_ISO. Build it first with: make iso"
}

vbox_machine_folder_arg() {
  if [[ -n "${VBOX_MACHINE_FOLDER:-}" ]]; then
    printf '%s\n' "--basefolder" "$VBOX_MACHINE_FOLDER"
  fi
}

vbox_print_summary() {
  log "VirtualBox VM: $VBOX_VM_NAME"
  log "State: $(vbox_power_state)"
  log "ISO: $ARTIFACT_ISO"
  log "Artifacts: $VBOX_ARTIFACT_DIR"
}
