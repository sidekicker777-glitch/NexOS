#!/usr/bin/env bash
# Builds the first bootable NexOS live ISO using Debian live-build.

set -Eeuo pipefail
BUILD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$BUILD_SCRIPT_DIR/lib/common.sh"

require_cmd lb
require_cmd tee
require_cmd sha256sum
require_cmd find

ensure_dir "$ISO_DIR"
ensure_dir "$LOG_DIR"

log "Preparing fresh live-build configuration."
# Use bash explicitly so Windows/GitHub web uploads cannot break this by
# stripping Linux executable permissions from scripts. Use BUILD_SCRIPT_DIR
# because common.sh defines its own SCRIPT_DIR for the shared library folder.
bash "$BUILD_SCRIPT_DIR/02-init-live-build.sh"

log "Injecting forced live login setup: username=$LIVE_USERNAME password=$LIVE_USERNAME"
cat > "$LB_CONFIG_DIR/hooks/normal/020-nexos-force-live-login.hook.chroot" <<HOOK
#!/usr/bin/env bash
set -euo pipefail

LIVE_USERNAME="$LIVE_USERNAME"
LIVE_FULLNAME="$LIVE_FULLNAME"
LIVE_PASSWORD="$LIVE_USERNAME"

if ! id "\$LIVE_USERNAME" >/dev/null 2>&1; then
  useradd -m -s /bin/bash -c "\$LIVE_FULLNAME" "\$LIVE_USERNAME"
fi

echo "\$LIVE_USERNAME:\$LIVE_PASSWORD" | chpasswd
usermod -U "\$LIVE_USERNAME" 2>/dev/null || true

for group in sudo audio video plugdev netdev users cdrom; do
  if getent group "\$group" >/dev/null 2>&1; then
    usermod -aG "\$group" "\$LIVE_USERNAME" || true
  fi
done

mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-nexos-live-autologin.conf <<LIGHTDM
[Seat:*]
autologin-user=$LIVE_USERNAME
autologin-user-timeout=0
autologin-session=xfce
user-session=xfce
greeter-session=lightdm-gtk-greeter
LIGHTDM

mkdir -p "/home/\$LIVE_USERNAME/Desktop"
cat > "/home/\$LIVE_USERNAME/Desktop/README-NexOS-Login.txt" <<README
NexOS live login:
Username: $LIVE_USERNAME
Password: $LIVE_USERNAME

Autologin should start automatically. If the login screen appears, use the credentials above.
README
chown -R "\$LIVE_USERNAME:\$LIVE_USERNAME" "/home/\$LIVE_USERNAME"
chmod 0755 "/home/\$LIVE_USERNAME/Desktop" || true
HOOK
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/020-nexos-force-live-login.hook.chroot"

log "Starting live-build. This downloads Debian packages and may take a while."
log "Target ISO: $ARTIFACT_ISO"

pushd "$LIVE_BUILD_DIR" >/dev/null

# Keep the build log even if live-build fails.
BUILD_LOG="$LOG_DIR/live-build-part2.log"
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  lb build 2>&1 | tee "$BUILD_LOG"
else
  sudo lb build 2>&1 | tee "$BUILD_LOG"
fi

popd >/dev/null

candidate="$(find "$LIVE_BUILD_DIR" -maxdepth 1 -type f \( -name '*.iso' -o -name '*.hybrid.iso' \) -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2- || true)"
if [[ -z "$candidate" || ! -f "$candidate" ]]; then
  fail "live-build finished but no ISO file was found in $LIVE_BUILD_DIR. Check $BUILD_LOG"
fi

cp -f "$candidate" "$ARTIFACT_ISO"
sha256sum "$ARTIFACT_ISO" > "$ARTIFACT_ISO.sha256"

success "ISO built: $ARTIFACT_ISO"
success "Checksum: $ARTIFACT_ISO.sha256"
log "Run: make validate-iso"
log "Optional quick boot test: make qemu-test"
