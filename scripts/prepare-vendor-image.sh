#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SPARSE_IMAGE="${1:-workdir/downloads/ubports-samsung-exynos9825-h11/vendor.img}"
OUTPUT_IMAGE="${2:-images-focal/vendor.img}"
HWC_RC="vendor-overlay/etc/init/android.hardware.graphics.composer@2.2-service.rc"
EXPECTED_SPARSE_SHA256="17d58ebd28e78202fa38ca54250aab76d6c0e9cfb0bab9a7931bd1f312f24860"
VENDOR_PARTITION_SIZE=1331691520

if [ -d "$ROOT/.local/usr/bin" ]; then
    export PATH="$ROOT/.local/usr/bin:$PATH"
    export LD_LIBRARY_PATH="$ROOT/.local/usr/lib/x86_64-linux-gnu/android:$ROOT/.local/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

test -f "$SPARSE_IMAGE"
test -f "$HWC_RC"
test "$(sha256sum "$SPARSE_IMAGE" | awk '{print $1}')" = "$EXPECTED_SPARSE_SHA256"
mkdir -p "$(dirname "$OUTPUT_IMAGE")"

TMP="$(mktemp -d "$ROOT/workdir/vendor-image.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
simg2img "$SPARSE_IMAGE" "$TMP/vendor.img"
test "$(stat -c '%s' "$TMP/vendor.img")" -le "$VENDOR_PARTITION_SIZE"
e2fsck -fn "$TMP/vendor.img" >/dev/null 2>&1

rc_path=etc/init/android.hardware.graphics.composer@2.2-service.rc
debugfs -w -R "rm $rc_path" "$TMP/vendor.img" >/dev/null 2>&1
debugfs -w -R "write $HWC_RC $rc_path" "$TMP/vendor.img" >/dev/null 2>&1
debugfs -w -R "set_inode_field $rc_path mode 0100644" "$TMP/vendor.img" >/dev/null 2>&1
printf 'u:object_r:vendor_configs_file:s0\0' > "$TMP/selinux-context"
debugfs -w -R "ea_set -f $TMP/selinux-context $rc_path security.selinux" \
    "$TMP/vendor.img" >/dev/null 2>&1

debugfs -R "cat $rc_path" "$TMP/vendor.img" 2>/dev/null | \
    grep -q 'interface android.hardware.graphics.composer@2.1::IComposer default'
debugfs -R "cat $rc_path" "$TMP/vendor.img" 2>/dev/null | grep -q '^on init$'
debugfs -R "stat $rc_path" "$TMP/vendor.img" 2>/dev/null | grep -q 'Mode:  0644'
debugfs -R "ea_list $rc_path" "$TMP/vendor.img" 2>&1 | \
    grep -q 'u:object_r:vendor_configs_file:s0'
e2fsck -fn "$TMP/vendor.img" >/dev/null 2>&1

install -m 0644 "$TMP/vendor.img" "$OUTPUT_IMAGE"
printf 'Patched D2S H11 vendor image ready: %s\n' "$OUTPUT_IMAGE"
