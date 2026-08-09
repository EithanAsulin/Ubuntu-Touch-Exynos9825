#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SYSTEM_IMAGE="${1:-images-focal/ubuntu.img}"
OUTPUT_NAME="${2:-ubuntu-touch-focal-d2s-system-update.zip}"
OUTPUT_DIR="${3:-sideload-focal}"
UPDATER_SOURCE="${UPDATER_SOURCE:-$OUTPUT_DIR/ubuntu-touch-focal-d2s-rc2.zip}"
UPDATER_SHA256="0d47f97f164f18b3d6e81060680f5bfcd4ba1f59fa50f3f418cc9c36b3d36b31"
SYSTEM_PARTITION_SIZE=6502219776

test -f "$SYSTEM_IMAGE"
test -f "$UPDATER_SOURCE"
test "$(stat -c '%s' "$SYSTEM_IMAGE")" -le "$SYSTEM_PARTITION_SIZE"

TMP="$(mktemp -d "$ROOT/workdir/system-update.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/stage/META-INF/com/google/android"

install -m 0644 sideload-assets/system-update-updater-script \
    "$TMP/stage/META-INF/com/google/android/updater-script"
unzip -p "$UPDATER_SOURCE" META-INF/com/google/android/update-binary > \
    "$TMP/stage/META-INF/com/google/android/update-binary"
test "$(sha256sum "$TMP/stage/META-INF/com/google/android/update-binary" | awk '{print $1}')" = \
    "$UPDATER_SHA256"
chmod 0755 "$TMP/stage/META-INF/com/google/android/update-binary"
cp --reflink=auto "$SYSTEM_IMAGE" "$TMP/stage/ubuntu.img"
chmod 0644 "$TMP/stage/ubuntu.img"

(
    cd "$TMP/stage"
    sha256sum ubuntu.img META-INF/com/google/android/update-binary \
        META-INF/com/google/android/updater-script > SHA256SUMS
    zip -1 -X -q -r "$TMP/$OUTPUT_NAME" META-INF SHA256SUMS ubuntu.img
)

unzip -tq "$TMP/$OUTPUT_NAME"
image_sha="$(sha256sum "$SYSTEM_IMAGE" | awk '{print $1}')"
test "$(unzip -p "$TMP/$OUTPUT_NAME" ubuntu.img | sha256sum | awk '{print $1}')" = \
    "$image_sha"

mkdir -p "$OUTPUT_DIR"
install -m 0644 "$TMP/$OUTPUT_NAME" "$OUTPUT_DIR/$OUTPUT_NAME"
(
    cd "$OUTPUT_DIR"
    sha256sum "$OUTPUT_NAME" > "$OUTPUT_NAME.sha256"
)

printf 'Non-wiping SYSTEM update ready: %s/%s\n' "$ROOT/$OUTPUT_DIR" "$OUTPUT_NAME"
