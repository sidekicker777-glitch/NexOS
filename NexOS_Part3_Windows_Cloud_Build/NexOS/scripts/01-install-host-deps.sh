#!/usr/bin/env bash
# Installs NexOS host dependencies on Debian/Ubuntu build hosts.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

if ! is_debian_like; then
  fail "This dependency installer supports Debian/Ubuntu-like hosts only. See docs/build-setup.md for manual package mapping."
fi

if ! need_cmd sudo && [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  fail "sudo is required to install packages from a normal user account."
fi

log "Installing NexOS Part 2 build dependencies. You may be asked for your sudo password."

sudo_cmd apt-get update
sudo_cmd apt-get install -y \
  bash \
  ca-certificates \
  coreutils \
  curl \
  debootstrap \
  dosfstools \
  file \
  findutils \
  git \
  gnupg \
  grep \
  gzip \
  live-build \
  make \
  mtools \
  parted \
  rsync \
  sed \
  squashfs-tools \
  syslinux-common \
  syslinux-utils \
  tar \
  wget \
  xorriso \
  qemu-system-x86 \
  qemu-utils \
  ovmf

warn "VirtualBox is not installed automatically because package names vary by host. Install VirtualBox separately if you want GUI VM testing."
success "Build dependencies installed."
