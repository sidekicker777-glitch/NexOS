#!/usr/bin/env bash
# Compatibility wrapper kept from Part 2. Prefer: make vbox-create
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/vbox-create.sh" "$@"
