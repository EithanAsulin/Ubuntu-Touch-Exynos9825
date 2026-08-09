#!/bin/bash
# Build a recovery sideload that formats the D2S USERDATA partition as ext4.
# This fixes the bootloop where userdata (F2FS) mounts with "Invalid argument".
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

UPDATER_SCRIPT="sideload-assets/userdata-ext4-updater-script"
UPDATER_SOURCE="sideload-focal/ubuntu-touch-focal-d2s-rc2.zip"
UPDATER_SHA256="0d47f97f164f18b3d6e81060680f5bfcd4ba1f59fa50f3f418cc9c36b3d36b31"
OUTPUT_NAME="ubuntu-touch-focal-d2s-userdata-ext4.zip"
OUTPUT_DIR="sideload-focal"

test -f "$UPDATER_SCRIPT"
test -f "$UPDATER_SOURCE"

TMP="$(mktemp -d "$ROOT/workdir/userdata-ext4.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/stage/META-INF/com/google/android"

install -m 0644 "$UPDATER_SCRIPT" \
    "$TMP/stage/META-INF/com/google/android/updater-script"
unzip -p "$UPDATER_SOURCE" META-INF/com/google/android/update-binary > \
    "$TMP/stage/META-INF/com/google/android/update-binary"
test "$(sha256sum "$TMP/stage/META-INF/com/google/android/update-binary" | awk '{print $1}')" = \
    "$UPDATER_SHA256"
chmod 0755 "$TMP/stage/META-INF/com/google/android/update-binary"

(
    cd "$TMP/stage"
    sha256sum META-INF/com/google/android/update-binary \
        META-INF/com/google/android/updater-script > SHA256SUMS
    zip -1 -X -q -r "$TMP/$OUTPUT_NAME" META-INF SHA256SUMS
)

unzip -tq "$TMP/$OUTPUT_NAME"
mkdir -p "$OUTPUT_DIR"
install -m 0644 "$TMP/$OUTPUT_NAME" "$OUTPUT_DIR/$OUTPUT_NAME"
(
    cd "$OUTPUT_DIR"
    sha256sum "$OUTPUT_NAME" > "$OUTPUT_NAME.sha256"
)
printf 'USERDATA-ext4 package ready: %s/%s\n' "$ROOT/$OUTPUT_DIR" "$OUTPUT_NAME"
