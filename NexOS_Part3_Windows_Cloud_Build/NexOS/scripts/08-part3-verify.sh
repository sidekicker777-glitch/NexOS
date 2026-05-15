#!/usr/bin/env bash
# Verifies Part 3 VirtualBox workflow files without requiring VirtualBox to be installed.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

log "Verifying Part 3 VirtualBox workflow files."

for script in "$PROJECT_ROOT"/scripts/*.sh "$PROJECT_ROOT"/scripts/lib/*.sh "$PROJECT_ROOT"/testing/*.sh; do
  [[ -f "$script" ]] || continue
  bash -n "$script"
  success "Syntax OK: ${script#$PROJECT_ROOT/}"
done

required_files=(
  "$PROJECT_ROOT/testing/vbox-lib.sh"
  "$PROJECT_ROOT/testing/vbox-create.sh"
  "$PROJECT_ROOT/testing/vbox-start.sh"
  "$PROJECT_ROOT/testing/vbox-stop.sh"
  "$PROJECT_ROOT/testing/vbox-reset.sh"
  "$PROJECT_ROOT/testing/vbox-status.sh"
  "$PROJECT_ROOT/testing/vbox-attach-iso.sh"
  "$PROJECT_ROOT/testing/vbox-screenshot.sh"
  "$PROJECT_ROOT/testing/vbox-collect-logs.sh"
  "$PROJECT_ROOT/testing/vbox-clean.sh"
  "$PROJECT_ROOT/testing/vbox-full-live-test.sh"
  "$PROJECT_ROOT/docs/part-03-virtualbox-boot-testing.md"
  "$PROJECT_ROOT/testing/checklists/live-iso-boot-checklist.md"
)

for file in "${required_files[@]}"; do
  [[ -f "$file" ]] || fail "Missing Part 3 file: ${file#$PROJECT_ROOT/}"
  success "Found: ${file#$PROJECT_ROOT/}"
done

for file in "$PROJECT_ROOT"/testing/vbox-*.sh "$PROJECT_ROOT"/testing/create-vbox-vm.sh; do
  [[ -x "$file" ]] || fail "Script is not executable: ${file#$PROJECT_ROOT/}"
done

grep -q 'vbox-create:' "$PROJECT_ROOT/Makefile" || fail "Makefile missing vbox-create target"
grep -q 'part3-verify:' "$PROJECT_ROOT/Makefile" || fail "Makefile missing part3-verify target"
grep -q 'PROJECT_VERSION="0.3.0-part3"' "$CONFIG_FILE" || fail "Project version was not updated to Part 3"

if need_cmd VBoxManage; then
  success "VBoxManage is installed: $(VBoxManage --version)"
else
  warn "VBoxManage is not installed here. That is okay for verification; install VirtualBox on the test host before running vbox commands."
fi

success "Part 3 verification passed."
