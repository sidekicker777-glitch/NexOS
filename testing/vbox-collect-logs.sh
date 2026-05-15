#!/usr/bin/env bash
# Collects VirtualBox VM info and log files for debugging boot issues.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=vbox-lib.sh
source "$SCRIPT_DIR/vbox-lib.sh"

vbox_require
ensure_dir "$VBOX_INFO_DIR"
ensure_dir "$VBOX_COPIED_LOG_DIR"

ts="$(date +%Y%m%d-%H%M%S)"
report="$VBOX_INFO_DIR/${VBOX_VM_NAME}-${ts}-report.txt"

{
  echo "NexOS VirtualBox Test Report"
  echo "Generated: $(date -Is)"
  echo "Project: $PROJECT_NAME $PROJECT_VERSION"
  echo "ISO: $ARTIFACT_ISO"
  if [[ -f "$ARTIFACT_ISO.sha256" ]]; then
    echo "ISO SHA256: $(cat "$ARTIFACT_ISO.sha256")"
  fi
  echo
  echo "== Host info =="
  VBoxManage list hostinfo || true
  echo
  echo "== System properties =="
  VBoxManage list systemproperties || true
  echo
  echo "== VM info =="
  if vbox_exists; then
    VBoxManage showvminfo "$VBOX_VM_NAME" || true
  else
    echo "VM does not exist: $VBOX_VM_NAME"
  fi
} > "$report"

if vbox_exists; then
  if vm_folder="$(vbox_vm_folder)" && [[ -d "$vm_folder/Logs" ]]; then
    dest="$VBOX_COPIED_LOG_DIR/${VBOX_VM_NAME}-${ts}"
    ensure_dir "$dest"
    cp -f "$vm_folder"/Logs/VBox*.log* "$dest"/ 2>/dev/null || true
    success "Copied VirtualBox logs to: $dest"
  else
    warn "Could not find VirtualBox VM Logs folder."
  fi
fi

success "Report saved: $report"
