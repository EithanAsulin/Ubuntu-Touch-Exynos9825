#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ -d "$ROOT/.local/usr/bin" ]; then
    export PATH="$ROOT/.local/usr/bin:$PATH"
    export LD_LIBRARY_PATH="$ROOT/.local/usr/lib/x86_64-linux-gnu/android:$ROOT/.local/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

EVOLUTION_ZIP="${1:-$ROOT/../evolutionX/EvolutionX-16.0-20260713-d2s-11.9-Official.zip}"
SYSTEM_IMAGE="${2:-images-focal/ubuntu.img}"
BOOT_IMAGE="${3:-images-focal/boot.img}"
OUTPUT_DIR="${4:-sideload-focal}"
VENDOR_IMAGE="${5:-images-focal/vendor.img}"
VENDOR_SPARSE_SOURCE="${6:-workdir/downloads/ubports-samsung-exynos9825-h11/vendor.img}"
OUTPUT_NAME="${7:-ubuntu-touch-focal-d2s-sideload.zip}"
ASSETS="$ROOT/sideload-assets"
WAYDROID_SYSTEM_ZIP="${WAYDROID_SYSTEM_ZIP:-$ROOT/workdir/waydroid-images/lineage-20.0-20260403-VANILLA-waydroid_arm64-system.zip}"
WAYDROID_VENDOR_ZIP="${WAYDROID_VENDOR_ZIP:-$ROOT/workdir/waydroid-images/lineage-18.1-20260402-HALIUM_11-waydroid_arm64-vendor.zip}"

EXPECTED_UPDATER_SHA256="0d47f97f164f18b3d6e81060680f5bfcd4ba1f59fa50f3f418cc9c36b3d36b31"
SYSTEM_PARTITION_SIZE=6502219776
BOOT_PARTITION_SIZE=57671680
VENDOR_PARTITION_SIZE=1331691520
USERDATA_PARTITION_SIZE=246016901120

for file in \
    "$EVOLUTION_ZIP" \
    "$SYSTEM_IMAGE" \
    "$BOOT_IMAGE" \
    "$VENDOR_IMAGE" \
    "$VENDOR_SPARSE_SOURCE" \
    "$WAYDROID_SYSTEM_ZIP" \
    "$WAYDROID_VENDOR_ZIP" \
    "$ASSETS/META-INF/com/google/android/updater-script" \
    "$ASSETS/META-INF/com/android/metadata" \
    "$ASSETS/README.txt"; do
    if [ ! -f "$file" ]; then
        echo "Missing required file: $file" >&2
        exit 1
    fi
done

test "$(stat -c '%s' "$WAYDROID_SYSTEM_ZIP")" = 904855273
test "$(sha256sum "$WAYDROID_SYSTEM_ZIP" | awk '{print $1}')" = \
    c4b45fad36bee7c0db8a1d9315a5be0035520c53d3d005a807735ae9b7ee79cf
test "$(stat -c '%s' "$WAYDROID_VENDOR_ZIP")" = 42868809
test "$(sha256sum "$WAYDROID_VENDOR_ZIP" | awk '{print $1}')" = \
    5b48a2771e77ff9085862f58b5c9d852d439d5e57dd38ea33b58381c2b14ca48
unzip -tq "$WAYDROID_SYSTEM_ZIP"
unzip -tq "$WAYDROID_VENDOR_ZIP"

system_size=$(stat -c '%s' "$SYSTEM_IMAGE")
boot_size=$(stat -c '%s' "$BOOT_IMAGE")
if [ "$system_size" -gt "$SYSTEM_PARTITION_SIZE" ]; then
    echo "System image exceeds the live PIT SYSTEM capacity" >&2
    exit 1
fi

if [ "$(sha256sum "$VENDOR_SPARSE_SOURCE" | awk '{print $1}')" != \
     "17d58ebd28e78202fa38ca54250aab76d6c0e9cfb0bab9a7931bd1f312f24860" ]; then
    echo "Vendor source is not the pinned Halium 11 d2s image" >&2
    exit 1
fi
if [ "$boot_size" -gt "$BOOT_PARTITION_SIZE" ]; then
    echo "Boot image exceeds the live PIT BOOT capacity" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
TMP="$(mktemp -d "$ROOT/workdir/sideload.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/stage/META-INF/com/google/android" "$TMP/stage/META-INF/com/android"

cp --reflink=auto "$VENDOR_IMAGE" "$TMP/stage/vendor.img"
vendor_size=$(stat -c '%s' "$TMP/stage/vendor.img")
if [ "$vendor_size" -gt "$VENDOR_PARTITION_SIZE" ]; then
    echo "Expanded vendor image exceeds the live PIT VENDOR capacity" >&2
    exit 1
fi
e2fsck -fn "$TMP/stage/vendor.img" >/dev/null 2>&1
debugfs -R 'cat etc/init/android.hardware.graphics.composer@2.2-service.rc' \
    "$TMP/stage/vendor.img" 2>/dev/null | \
    grep -q 'interface android.hardware.graphics.composer@2.1::IComposer default'
debugfs -R 'cat etc/init/android.hardware.graphics.composer@2.2-service.rc' \
    "$TMP/stage/vendor.img" 2>/dev/null | grep -q '^on init$'
debugfs -R 'stat bin/hw/android.hardware.graphics.composer@2.2-service' \
    "$TMP/stage/vendor.img" 2>/dev/null | grep -q 'Type: regular'

grep -q "getsize64 /dev/block/platform/13d60000.ufs/by-name/userdata" \
    "$ASSETS/META-INF/com/google/android/updater-script"
grep -q "= $USERDATA_PARTITION_SIZE" \
    "$ASSETS/META-INF/com/google/android/updater-script"
grep -q 'mke2fs -t ext4' "$ASSETS/META-INF/com/google/android/updater-script"
grep -q 'do NOT run recovery Format Data' \
    "$ASSETS/META-INF/com/google/android/updater-script"

unzip -p "$EVOLUTION_ZIP" META-INF/com/google/android/update-binary > \
    "$TMP/stage/META-INF/com/google/android/update-binary"
test "$(sha256sum "$TMP/stage/META-INF/com/google/android/update-binary" | awk '{print $1}')" = \
    "$EXPECTED_UPDATER_SHA256"
chmod 0755 "$TMP/stage/META-INF/com/google/android/update-binary"

install -m 0644 \
    "$ASSETS/META-INF/com/google/android/updater-script" \
    "$TMP/stage/META-INF/com/google/android/updater-script"
install -m 0644 \
    "$ASSETS/META-INF/com/android/metadata" \
    "$TMP/stage/META-INF/com/android/metadata"
install -m 0644 "$ASSETS/README.txt" "$TMP/stage/README.txt"
cp --reflink=auto "$SYSTEM_IMAGE" "$TMP/stage/ubuntu.img"
cp --reflink=auto "$BOOT_IMAGE" "$TMP/stage/boot.img"
cp --reflink=auto "$WAYDROID_SYSTEM_ZIP" "$TMP/stage/waydroid-system.zip"
cp --reflink=auto "$WAYDROID_VENDOR_ZIP" "$TMP/stage/waydroid-vendor.zip"
chmod 0644 "$TMP/stage/ubuntu.img" "$TMP/stage/vendor.img" "$TMP/stage/boot.img"
chmod 0644 "$TMP/stage/waydroid-system.zip" "$TMP/stage/waydroid-vendor.zip"

(
    cd "$TMP/stage"
    sha256sum ubuntu.img vendor.img boot.img waydroid-system.zip waydroid-vendor.zip \
        META-INF/com/google/android/update-binary \
        META-INF/com/google/android/updater-script > SHA256SUMS
)

package_work="$TMP/$OUTPUT_NAME"
(
    cd "$TMP/stage"
    zip -1 -X -q -r "$package_work" \
        META-INF README.txt SHA256SUMS ubuntu.img vendor.img boot.img \
        waydroid-system.zip waydroid-vendor.zip
)

unzip -tq "$package_work"
system_sha=$(sha256sum "$SYSTEM_IMAGE" | awk '{print $1}')
boot_sha=$(sha256sum "$BOOT_IMAGE" | awk '{print $1}')
vendor_sha=$(sha256sum "$VENDOR_IMAGE" | awk '{print $1}')
test "$(unzip -p "$package_work" ubuntu.img | sha256sum | awk '{print $1}')" = "$system_sha"
test "$(unzip -p "$package_work" vendor.img | sha256sum | awk '{print $1}')" = "$vendor_sha"
test "$(unzip -p "$package_work" boot.img | sha256sum | awk '{print $1}')" = "$boot_sha"
test "$(unzip -p "$package_work" waydroid-system.zip | sha256sum | awk '{print $1}')" = \
    c4b45fad36bee7c0db8a1d9315a5be0035520c53d3d005a807735ae9b7ee79cf
test "$(unzip -p "$package_work" waydroid-vendor.zip | sha256sum | awk '{print $1}')" = \
    5b48a2771e77ff9085862f58b5c9d852d439d5e57dd38ea33b58381c2b14ca48

package="$OUTPUT_DIR/$OUTPUT_NAME"
mv -f "$package_work" "$package"
(
    cd "$OUTPUT_DIR"
    sha256sum "$OUTPUT_NAME" > "$OUTPUT_NAME.sha256"
)
install -m 0644 "$ASSETS/README.txt" "$OUTPUT_DIR/README.txt"
chmod 0644 "$package" "$OUTPUT_DIR/$OUTPUT_NAME.sha256" "$OUTPUT_DIR/README.txt"

printf 'ADB sideload package ready: %s\n' "$ROOT/$package"
printf 'Unsigned recovery ZIP: verify its .sha256 sidecar before sideloading.\n'
