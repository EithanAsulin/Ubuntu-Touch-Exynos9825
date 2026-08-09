#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DEVICE_TARBALL="${1:-out/device_d2s.tar.xz}"
OTA_DIR="${2:-ota-focal}"
PRIVATE_KEY="${D2S_SSH_PRIVATE_KEY:-keys/d2s_focal_ed25519}"
PUBLIC_KEY="${D2S_SSH_PUBLIC_KEY:-${PRIVATE_KEY}.pub}"
BUILD_PATCH="patches/build-tools/0001-require-key-only-ssh.patch"
H11_GSI_TARBALL="${H11_GSI_TARBALL:-workdir/downloads/halium_halium_arm64-h11.tar.xz}"
H11_GSI_SHA256="d6946b3fa4fe733c391f8242479ce6c4e69736c86cfd70fcab16f525d357af0e"

if [ ! -d build/.git ]; then
    echo "Run ./build.sh -b workdir first so the pinned build tools are available." >&2
    exit 1
fi

if git -C build apply --check "$ROOT/$BUILD_PATCH" 2>/dev/null; then
    git -C build apply "$ROOT/$BUILD_PATCH"
elif ! git -C build apply --reverse --check "$ROOT/$BUILD_PATCH" 2>/dev/null; then
    # Local port development may extend the security patch after it was
    # applied.  Accept that state only when every required invariant remains.
    grep -q 'AuthenticationMethods publickey' build/prepare-fake-ota.sh
    grep -q 'touch /var/lib/dhcp/dhcpd.leases' build/prepare-fake-ota.sh
    grep -q 'd2s-keep-display-on.service' build/prepare-fake-ota.sh
    grep -q 'd2s-spen-touch-bridge.service' build/prepare-fake-ota.sh
    grep -q 'module-droid-card-29' build/prepare-fake-ota.sh
    grep -q 'd2s-android-audio.service' build/prepare-fake-ota.sh
    grep -q 'CHROME_DEB_SHA256' build/prepare-fake-ota.sh
    grep -q 'd2s-chrome' build/prepare-fake-ota.sh
    grep -q 'Type=simple' build/prepare-fake-ota.sh
    grep -q 'ADBD_SECURE=1' build/prepare-fake-ota.sh
fi

if [ ! -f "$PUBLIC_KEY" ]; then
    if [ -n "${D2S_SSH_PUBLIC_KEY:-}" ]; then
        echo "Configured public key does not exist: $PUBLIC_KEY" >&2
        exit 1
    fi
    mkdir -p "$(dirname "$PRIVATE_KEY")"
    umask 077
    ssh-keygen -q -t ed25519 -N "" -C "ubuntu-touch-d2s-focal" -f "$PRIVATE_KEY"
fi

ssh-keygen -l -f "$PUBLIC_KEY"
test -f "$H11_GSI_TARBALL"
test "$(sha256sum "$H11_GSI_TARBALL" | awk '{print $1}')" = "$H11_GSI_SHA256"
mkdir -p "$OTA_DIR"
# The H11 and H12 Jenkins artifacts share a basename.  Seed the OTA directory
# explicitly so a stale H12 download can never be silently reused.
install -m 0644 "$H11_GSI_TARBALL" "$OTA_DIR/halium_halium_arm64.tar.xz"
FAKEROOTDONTTRYCHOWN=1 SSH_PUBLIC_KEY_FILE="$(realpath "$PUBLIC_KEY")" \
    exec ./build/prepare-fake-ota.sh "$DEVICE_TARBALL" "$OTA_DIR"
