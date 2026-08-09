#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_RAMDISK="${1:-$ROOT/workdir/downloads/halium-boot-ramdisk.img}"
KERNEL_DIR="$(realpath "${2:-$ROOT/workdir/downloads/kernel-samsung-exynos9820}")"
KERNEL_OBJ_DIR="${D2S_KERNEL_OBJ_DIR:-$(dirname "$KERNEL_DIR")/KERNEL_OBJ}"
VENDOR_IMAGE="${D2S_VENDOR_IMAGE:-$ROOT/workdir/downloads/ubports-samsung-exynos9825-h11/vendor.img}"
BASE_RAMDISK="$(realpath "$BASE_RAMDISK")"
PATCH_FILE="$ROOT/patches/ramdisk/0001-support-ext4-and-f2fs-userdata.patch"
OUTPUT="$ROOT/ramdisk-overlay/scripts/halium"

if [ ! -f "$BASE_RAMDISK" ]; then
    echo "Missing base Halium ramdisk: $BASE_RAMDISK" >&2
    exit 1
fi
TMP="$(mktemp -d "$ROOT/workdir/ramdisk-overlay.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

gzip -dc "$BASE_RAMDISK" | cpio -i --quiet --to-stdout scripts/halium > "$TMP/halium"
patch --batch --forward -d "$TMP" -p0 < "$PATCH_FILE"
install -m 0755 "$TMP/halium" "$OUTPUT"

# Preserve the stock built-in NPU firmware while making the old Samsung
# kernel's out-of-tree build reproducible. This is unrelated to haptics.
test "$(sha256sum "$VENDOR_IMAGE" | awk '{print $1}')" = \
    17d58ebd28e78202fa38ca54250aab76d6c0e9cfb0bab9a7931bd1f312f24860
if command -v simg2img >/dev/null 2>&1; then
    LD_LIBRARY_PATH="$ROOT/.local/usr/lib/x86_64-linux-gnu/android:$ROOT/.local/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
        simg2img "$VENDOR_IMAGE" "$TMP/vendor.raw.img"
else
    LD_LIBRARY_PATH="$ROOT/.local/usr/lib/x86_64-linux-gnu/android:$ROOT/.local/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
        "$ROOT/.local/usr/bin/simg2img" "$VENDOR_IMAGE" "$TMP/vendor.raw.img"
fi
mkdir -p "$TMP/firmware" "$KERNEL_DIR/firmware/npu" "$KERNEL_OBJ_DIR/firmware/npu"
debugfs -R "dump firmware/NPU.bin $TMP/firmware/NPU.bin" \
    "$TMP/vendor.raw.img" >/dev/null 2>&1
test "$(sha256sum "$TMP/firmware/NPU.bin" | awk '{print $1}')" = \
    d822075147f1b5cde0d86a5c89c850c5fce6f11927b5e0a3069b05a2757dc287
install -m 0644 "$TMP/firmware/NPU.bin" "$KERNEL_DIR/firmware/npu/NPU.bin"
install -m 0644 "$TMP/firmware/NPU.bin" "$KERNEL_OBJ_DIR/firmware/npu/NPU.bin"

# CS40L25A haptic firmware is intentionally NOT embedded here: the firmware
# rebuild that embedded it caused a cold-boot bootloop (investigated 2026-08-07).
# The anbox binder nodes + scheduler fix are the Waydroid prerequisite and are
# kept separate. Re-add firmware only after the bootloop is understood.

grep -q 'using F2FS userdata without ext4 repair/resize' "$OUTPUT"
