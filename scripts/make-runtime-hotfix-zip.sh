#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUTPUT_NAME="ubuntu-touch-focal-d2s-runtime-repair.zip"
OUTPUT="$ROOT/sideload-focal/$OUTPUT_NAME"
UPDATER_SOURCE="$ROOT/sideload-focal/ubuntu-touch-focal-d2s-sideload.zip"
UPDATER_SHA256="0d47f97f164f18b3d6e81060680f5bfcd4ba1f59fa50f3f418cc9c36b3d36b31"
TMP="$(mktemp -d "$ROOT/workdir/runtime-repair.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/stage/META-INF/com/google/android" \
    "$TMP/stage/rootfs/usr/local/sbin" \
    "$TMP/stage/rootfs/etc/systemd/system/lxc-android-config.service.d" \
    "$TMP/stage/rootfs/usr/lib/waydroid/tools/helpers"

install -m 0644 sideload-assets/runtime-hotfix-updater-script \
    "$TMP/stage/META-INF/com/google/android/updater-script"
unzip -p "$UPDATER_SOURCE" META-INF/com/google/android/update-binary > \
    "$TMP/stage/META-INF/com/google/android/update-binary"
test "$(sha256sum "$TMP/stage/META-INF/com/google/android/update-binary" | awk '{print $1}')" = \
    "$UPDATER_SHA256"
chmod 0755 "$TMP/stage/META-INF/com/google/android/update-binary"
install -m 0755 runtime-fixes/d2s-android-compat \
    "$TMP/stage/rootfs/usr/local/sbin/d2s-android-compat"
install -m 0755 runtime-fixes/d2s-waydroid-offline-init \
    "$TMP/stage/rootfs/usr/local/sbin/d2s-waydroid-offline-init"
install -m 0644 runtime-fixes/d2s-android-compat.service \
    "$TMP/stage/rootfs/etc/systemd/system/d2s-android-compat.service"
install -m 0644 runtime-fixes/lxc-android-config-d2s.conf \
    "$TMP/stage/rootfs/etc/systemd/system/lxc-android-config.service.d/d2s-compat.conf"
install -m 0644 runtime-fixes/d2s-waydroid-offline-init.service \
    "$TMP/stage/rootfs/etc/systemd/system/d2s-waydroid-offline-init.service"
install -m 0644 runtime-fixes/waydroid-drivers.py \
    "$TMP/stage/rootfs/usr/lib/waydroid/tools/helpers/drivers.py"

dpkg-deb -x workdir/gstreamer1.0-tools_1.16.3-0ubuntu1.2_arm64.deb \
    "$TMP/stage/rootfs"
install -m 0644 images-focal/boot.img "$TMP/stage/boot.img"

test "$(stat -c '%s' "$TMP/stage/boot.img")" -le 57671680
test "$(sha256sum workdir/gstreamer1.0-tools_1.16.3-0ubuntu1.2_arm64.deb | awk '{print $1}')" = \
    f6778cff4b49694fe2f1c8319d726d518f076efca79deb9d329b958c9f86e4d8
test -x "$TMP/stage/rootfs/usr/bin/gst-inspect-1.0"
test -x "$TMP/stage/rootfs/usr/bin/gst-launch-1.0"

(
    cd "$TMP/stage"
    find META-INF rootfs -type f -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
    sha256sum boot.img >> SHA256SUMS
    zip -q -r -9 -X "$TMP/$OUTPUT_NAME" META-INF rootfs SHA256SUMS boot.img
)

mkdir -p "$ROOT/sideload-focal"
install -m 0644 "$TMP/$OUTPUT_NAME" "$OUTPUT"
(
    cd "$ROOT/sideload-focal"
    sha256sum "$OUTPUT_NAME" > "$OUTPUT_NAME.sha256"
)

unzip -tq "$OUTPUT"
test "$(unzip -p "$OUTPUT" META-INF/com/google/android/update-binary | sha256sum | awk '{print $1}')" = \
    "$UPDATER_SHA256"
unzip -p "$OUTPUT" boot.img | sha256sum | \
    grep -q "^$(sha256sum images-focal/boot.img | awk '{print $1}')  -$"
echo "Built $OUTPUT"
cat "$OUTPUT.sha256"
