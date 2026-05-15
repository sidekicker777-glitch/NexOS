#!/usr/bin/env bash
# Host validation. Safe to run without root.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

missing=0

log "Checking host for $PROJECT_NAME $PROJECT_VERSION"

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  warn "You are running as root. Use a normal user and let scripts ask for sudo only when needed."
fi

if ! is_debian_like; then
  warn "This host is not detected as Debian/Ubuntu-like. NexOS currently expects apt-based live-build tools."
  missing=1
else
  success "Debian/Ubuntu-like host detected."
  codename="$(host_codename || true)"
  if [[ "$codename" != "$BASE_CODENAME" ]]; then
    warn "Host codename is '$codename'; target is '$BASE_CODENAME'. Best result: build on Debian $BASE_CODENAME."
  else
    success "Host codename matches target: $BASE_CODENAME"
  fi
fi

available_gb="$(free_space_gb)"
if (( available_gb < MIN_FREE_SPACE_GB )); then
  warn "Free space is ${available_gb}GB. Minimum recommended for building is ${MIN_FREE_SPACE_GB}GB."
  missing=1
else
  success "Free space OK: ${available_gb}GB available."
fi

available_ram="$(ram_mb)"
if (( available_ram < MIN_RAM_MB )); then
  warn "RAM is ${available_ram}MB. Minimum recommended is ${MIN_RAM_MB}MB."
  missing=1
else
  success "RAM OK: ${available_ram}MB detected."
fi

required_now=(bash make sed awk grep find xargs df git)
for cmd in "${required_now[@]}"; do
  if need_cmd "$cmd"; then
    success "Found command: $cmd"
  else
    warn "Missing command: $cmd"
    missing=1
  fi
done

build_after_deps=(lb debootstrap mksquashfs xorriso sha256sum file)
for cmd in "${build_after_deps[@]}"; do
  if need_cmd "$cmd"; then
    success "Build command available: $cmd"
  else
    warn "Build command not installed yet: $cmd"
  fi
done

optional_test=(qemu-system-x86_64 VBoxManage)
for cmd in "${optional_test[@]}"; do
  if need_cmd "$cmd"; then
    success "Optional test command available: $cmd"
  else
    warn "Optional test command not installed: $cmd"
  fi
 done

if (( missing != 0 )); then
  warn "Host check completed with warnings. Run: make deps"
  exit 2
fi

success "Host check passed."
