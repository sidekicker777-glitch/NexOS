#!/usr/bin/env bash
# Shared helpers for NexOS build scripts.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/build-config/nexos.conf"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "[ERROR] Missing config file: $CONFIG_FILE" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

LIVE_BUILD_DIR="$PROJECT_ROOT/live-build"
LB_CONFIG_DIR="$LIVE_BUILD_DIR/config"
ISO_DIR="$PROJECT_ROOT/iso"
LOG_DIR="$PROJECT_ROOT/build/logs"
ARTIFACT_ISO="$ISO_DIR/$ISO_IMAGE_NAME"

COLOR_BLUE='\033[0;34m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
COLOR_RESET='\033[0m'

log() {
  echo -e "${COLOR_BLUE}[NexOS]${COLOR_RESET} $*"
}

success() {
  echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} $*"
}

warn() {
  echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*"
}

fail() {
  echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
  exit 1
}

need_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || return 1
}

require_cmd() {
  local cmd="$1"
  need_cmd "$cmd" || fail "Required command not found: $cmd"
}

is_debian_like() {
  [[ -f /etc/os-release ]] || return 1
  # shellcheck source=/dev/null
  source /etc/os-release
  [[ "${ID:-}" == "debian" || "${ID_LIKE:-}" == *"debian"* || "${ID:-}" == "ubuntu" ]]
}

host_codename() {
  [[ -f /etc/os-release ]] || return 1
  # shellcheck source=/dev/null
  source /etc/os-release
  echo "${VERSION_CODENAME:-unknown}"
}

free_space_gb() {
  df -BG "$PROJECT_ROOT" | awk 'NR==2 {gsub("G", "", $4); print $4}'
}

ram_mb() {
  awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo
}

ensure_dir() {
  mkdir -p "$1"
}

run_or_fail() {
  log "$*"
  "$@"
}

sudo_cmd() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

write_file() {
  local path="$1"
  ensure_dir "$(dirname "$path")"
  cat > "$path"
}
