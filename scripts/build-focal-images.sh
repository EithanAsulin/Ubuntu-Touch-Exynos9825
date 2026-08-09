#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DEVICE_TARBALL="${1:-out/device_d2s.tar.xz}"
OTA_DIR="${2:-ota-focal}"
IMAGE_DIR="${3:-images-focal}"
BUILD_PATCH="patches/build-tools/0002-rootless-system-image.patch"

if [ ! -f "$DEVICE_TARBALL" ] || [ ! -f "$OTA_DIR/ubuntu_command" ]; then
    echo "Build the device tarball and prepare the Focal OTA directory first." >&2
    exit 1
fi

if git -C build apply --check "$ROOT/$BUILD_PATCH" 2>/dev/null; then
    git -C build apply "$ROOT/$BUILD_PATCH"
elif ! git -C build apply --reverse --check "$ROOT/$BUILD_PATCH" 2>/dev/null; then
    echo "Build tools are neither clean nor rootless-patched as expected." >&2
    exit 1
fi

cp "$DEVICE_TARBALL" "$OTA_DIR/$(basename "$DEVICE_TARBALL")"
mkdir -p "$IMAGE_DIR"

if [ -d "$ROOT/.local/usr/bin" ]; then
    export PATH="$ROOT/.local/usr/bin:$PATH"
    export LD_LIBRARY_PATH="$ROOT/.local/usr/lib/x86_64-linux-gnu/android:$ROOT/.local/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

FAKEROOTDONTTRYCHOWN=1 SYSTEM_IMAGE_ROOTLESS=1 \
SYSTEM_IMAGE_WORKDIR="$ROOT/workdir/system-image-rootless" fakeroot -- \
    ./build/system-image-from-ota.sh "$OTA_DIR/ubuntu_command" "$IMAGE_DIR"

mv -f "$IMAGE_DIR/rootfs.img" "$IMAGE_DIR/ubuntu.img"
zstd -f -19 -T0 "$IMAGE_DIR/ubuntu.img" -o "$IMAGE_DIR/ubuntu.img.zst"
