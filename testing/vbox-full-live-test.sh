#!/usr/bin/env bash
# Runs the host-side VirtualBox test workflow for NexOS.
# This script cannot prove the desktop booted by itself; it creates the VM,
# starts it, captures a screenshot, and collects logs for human review.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=vbox-lib.sh
source "$SCRIPT_DIR/vbox-lib.sh"

mode="gui"
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
vbox_iso_ready

if ! vbox_exists; then
  "$SCRIPT_DIR/vbox-create.sh"
fi

"$SCRIPT_DIR/vbox-start.sh" "--$mode"

cat <<MESSAGE

NexOS VM is starting now.
Manual checks to perform in the VirtualBox window:
  1. Boot menu appears.
  2. Live desktop loads.
  3. Mouse and keyboard work.
  4. Terminal opens.
  5. nexos-info runs.
  6. File manager opens.
  7. Network works.

After the desktop appears, run:
  make vbox-screenshot
  make vbox-logs

MESSAGE
