#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-$ROOT/sideload-focal}"
OUTPUT_NAME="ubuntu-touch-focal-d2s-waydroid-finalize.zip"
TMP="$(mktemp -d "$ROOT/workdir/waydroid-finalize.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/META-INF/com/google/android" "$TMP/META-INF/com/android"
unzip -p "$ROOT/sideload-focal/ubuntu-touch-focal-d2s-sideload.zip" \
    META-INF/com/google/android/update-binary > \
    "$TMP/META-INF/com/google/android/update-binary"
install -m 0644 "$ROOT/sideload-assets/waydroid-finalize-updater-script" \
    "$TMP/META-INF/com/google/android/updater-script"
install -m 0644 "$ROOT/sideload-assets/META-INF/com/android/metadata" \
    "$TMP/META-INF/com/android/metadata"
chmod 0755 "$TMP/META-INF/com/google/android/update-binary"

mkdir -p "$OUTPUT_DIR"
(
    cd "$TMP"
    zip -9 -X -q -r "$OUTPUT_NAME" META-INF
)
unzip -tq "$TMP/$OUTPUT_NAME"
mv -f "$TMP/$OUTPUT_NAME" "$OUTPUT_DIR/$OUTPUT_NAME"
(
    cd "$OUTPUT_DIR"
    sha256sum "$OUTPUT_NAME" > "$OUTPUT_NAME.sha256"
)
printf 'Finalizer ready: %s/%s\n' "$OUTPUT_DIR" "$OUTPUT_NAME"
