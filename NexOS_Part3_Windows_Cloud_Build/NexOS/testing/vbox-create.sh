#!/usr/bin/env bash
# Creates/recreates the NexOS VirtualBox VM used for ISO boot testing.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=vbox-lib.sh
source "$SCRIPT_DIR/vbox-lib.sh"

usage() {
  cat <<USAGE
Usage: $0 [--force]

Creates the NexOS VirtualBox test VM and attaches the generated ISO.

Options:
  --force   Power off and delete the existing VM before recreating it.
USAGE
}

force="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) force="true" ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
  shift
done

vbox_require
vbox_iso_ready
ensure_dir "$VBOX_ARTIFACT_DIR"

VM_DISK_PATH="$SCRIPT_DIR/${VBOX_VM_NAME}.vdi"

if vbox_exists; then
  if [[ "$force" == "true" ]]; then
    vbox_poweroff_if_running
    warn "Deleting existing VM: $VBOX_VM_NAME"
    VBoxManage unregistervm "$VBOX_VM_NAME" --delete >/dev/null
    rm -f "$VM_DISK_PATH"
  else
    fail "VM '$VBOX_VM_NAME' already exists. Use: make vbox-reset or ./testing/vbox-create.sh --force"
  fi
fi

log "Creating VirtualBox VM: $VBOX_VM_NAME"
create_args=(createvm --name "$VBOX_VM_NAME" --ostype "$VBOX_OS_TYPE" --register)
if [[ -n "${VBOX_MACHINE_FOLDER:-}" ]]; then
  create_args+=(--basefolder "$VBOX_MACHINE_FOLDER")
fi
VBoxManage "${create_args[@]}" >/dev/null

VBoxManage modifyvm "$VBOX_VM_NAME" \
  --memory "$VBOX_RAM_MB" \
  --cpus "$VBOX_CPUS" \
  --vram "$VBOX_VRAM_MB" \
  --graphicscontroller "$VBOX_GRAPHICS" \
  --nic1 nat \
  --audiocontroller hda \
  --audio-enabled on \
  --mouse usbtablet \
  --keyboard usb \
  --clipboard "${VBOX_SHARED_CLIPBOARD:-bidirectional}" \
  --draganddrop "${VBOX_DRAG_AND_DROP:-bidirectional}" \
  --boot1 dvd \
  --boot2 disk \
  --boot3 none \
  --boot4 none

if [[ "$VBOX_FIRMWARE" == "efi" ]]; then
  VBoxManage modifyvm "$VBOX_VM_NAME" --firmware efi
else
  VBoxManage modifyvm "$VBOX_VM_NAME" --firmware bios
fi

VBoxManage createmedium disk --filename "$VM_DISK_PATH" --size "$VBOX_DISK_MB" --format VDI >/dev/null
VBoxManage storagectl "$VBOX_VM_NAME" --name "SATA Controller" --add sata --controller IntelAhci >/dev/null
VBoxManage storageattach "$VBOX_VM_NAME" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$VM_DISK_PATH" >/dev/null
VBoxManage storagectl "$VBOX_VM_NAME" --name "IDE Controller" --add ide >/dev/null
VBoxManage storageattach "$VBOX_VM_NAME" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium "$ARTIFACT_ISO" >/dev/null

VBoxManage snapshot "$VBOX_VM_NAME" take "${VBOX_SNAPSHOT_NAME:-Fresh-Live-ISO-Test}" --description "Clean NexOS live ISO test VM" >/dev/null

success "VirtualBox VM created: $VBOX_VM_NAME"
vbox_print_summary
log "Start it with: make vbox-start"
