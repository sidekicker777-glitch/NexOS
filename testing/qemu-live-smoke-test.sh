#!/usr/bin/env bash
# Boots the generated ISO in QEMU for a quick smoke test.
# This is not a replacement for the required VirtualBox checklist.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/lib/common.sh
source "$SCRIPT_DIR/../scripts/lib/common.sh"

require_cmd qemu-system-x86_64
[[ -f "$ARTIFACT_ISO" ]] || fail "Missing ISO: $ARTIFACT_ISO. Build it first with: make iso"

kvm_args=()
if [[ -e /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; then
  kvm_args=(-enable-kvm)
else
  warn "KVM acceleration is unavailable. QEMU will run slower."
fi

log "Starting QEMU live ISO smoke test. Close the QEMU window to end the test."
qemu-system-x86_64 \
  "${kvm_args[@]}" \
  -m "$VBOX_RAM_MB" \
  -smp "$VBOX_CPUS" \
  -cdrom "$ARTIFACT_ISO" \
  -boot d \
  -vga virtio \
  -device qemu-xhci \
  -device usb-tablet \
  -netdev user,id=net0 \
  -device e1000,netdev=net0
