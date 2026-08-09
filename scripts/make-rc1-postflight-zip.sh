#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUTPUT_NAME="ubuntu-touch-focal-d2s-rc1-postflight.zip"
OUTPUT_DIR="$ROOT/sideload-focal"
SOURCE_ZIP="$OUTPUT_DIR/ubuntu-touch-focal-d2s-rc1.zip"
UPDATER_SHA256="0d47f97f164f18b3d6e81060680f5bfcd4ba1f59fa50f3f418cc9c36b3d36b31"
TMP="$(mktemp -d "$ROOT/workdir/rc1-postflight.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/META-INF/com/google/android"
unzip -p "$SOURCE_ZIP" META-INF/com/google/android/update-binary > \
    "$TMP/META-INF/com/google/android/update-binary"
test "$(sha256sum "$TMP/META-INF/com/google/android/update-binary" | awk '{print $1}')" = \
    "$UPDATER_SHA256"
chmod 0755 "$TMP/META-INF/com/google/android/update-binary"
install -m 0644 sideload-assets/rc1-postflight-updater-script \
    "$TMP/META-INF/com/google/android/updater-script"

(
    cd "$TMP"
    zip -9 -X -q -r "$OUTPUT_NAME" META-INF
)
unzip -tq "$TMP/$OUTPUT_NAME"
install -m 0644 "$TMP/$OUTPUT_NAME" "$OUTPUT_DIR/$OUTPUT_NAME"
(
    cd "$OUTPUT_DIR"
    sha256sum "$OUTPUT_NAME" > "$OUTPUT_NAME.sha256"
)

echo "Built $OUTPUT_DIR/$OUTPUT_NAME"
cat "$OUTPUT_DIR/$OUTPUT_NAME.sha256"
