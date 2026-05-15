#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"

required_files=(
  "$ROOT_DIR/.github/workflows/build-nexos-iso.yml"
  "$ROOT_DIR/docs/windows-no-linux-build.md"
  "$ROOT_DIR/Makefile"
  "$ROOT_DIR/scripts/05-build-live-iso.sh"
  "$ROOT_DIR/scripts/06-validate-iso.sh"
)

for file in "${required_files[@]}"; do
  [[ -f "$file" ]] || fail "Missing required file: $file"
done

if ! grep -q "workflow_dispatch" "$ROOT_DIR/.github/workflows/build-nexos-iso.yml"; then
  fail "GitHub Actions workflow must support manual workflow_dispatch runs."
fi

if ! grep -q "actions/upload-artifact@v4" "$ROOT_DIR/.github/workflows/build-nexos-iso.yml"; then
  fail "GitHub Actions workflow must upload the finished ISO artifact."
fi

if ! grep -q "docker run --privileged" "$ROOT_DIR/.github/workflows/build-nexos-iso.yml"; then
  fail "GitHub Actions workflow must build inside a privileged Debian container for live-build."
fi

success "Windows/cloud ISO build workflow verification passed."
