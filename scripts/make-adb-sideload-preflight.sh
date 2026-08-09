#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EVOLUTION_ZIP="${1:-$ROOT/../evolutionX/EvolutionX-16.0-20260713-d2s-11.9-Official.zip}"
OUTPUT_DIR="${2:-sideload-focal}"
OUTPUT_NAME="ubuntu-touch-focal-d2s-preflight.zip"
ASSETS="$ROOT/sideload-assets"
EXPECTED_UPDATER_SHA256="0d47f97f164f18b3d6e81060680f5bfcd4ba1f59fa50f3f418cc9c36b3d36b31"

for file in \
    "$EVOLUTION_ZIP" \
    "$ASSETS/preflight-updater-script" \
    "$ASSETS/META-INF/com/android/metadata" \
    "$ASSETS/PREFLIGHT-README.txt"; do
    if [ ! -f "$file" ]; then
        echo "Missing required file: $file" >&2
        exit 1
    fi
done

mkdir -p "$OUTPUT_DIR"
TMP="$(mktemp -d "$ROOT/workdir/sideload-preflight.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/stage/META-INF/com/google/android" "$TMP/stage/META-INF/com/android"

unzip -p "$EVOLUTION_ZIP" META-INF/com/google/android/update-binary > \
    "$TMP/stage/META-INF/com/google/android/update-binary"
test "$(sha256sum "$TMP/stage/META-INF/com/google/android/update-binary" | awk '{print $1}')" = \
    "$EXPECTED_UPDATER_SHA256"
chmod 0755 "$TMP/stage/META-INF/com/google/android/update-binary"
install -m 0644 "$ASSETS/preflight-updater-script" \
    "$TMP/stage/META-INF/com/google/android/updater-script"
install -m 0644 "$ASSETS/META-INF/com/android/metadata" \
    "$TMP/stage/META-INF/com/android/metadata"
install -m 0644 "$ASSETS/PREFLIGHT-README.txt" "$TMP/stage/README.txt"

package_work="$TMP/$OUTPUT_NAME"
(
    cd "$TMP/stage"
    zip -9 -X -q -r "$package_work" META-INF README.txt
)
unzip -tq "$package_work"
unzip -p "$package_work" META-INF/com/google/android/updater-script | \
    cmp - "$ASSETS/preflight-updater-script"

package="$OUTPUT_DIR/$OUTPUT_NAME"
mv -f "$package_work" "$package"
(
    cd "$OUTPUT_DIR"
    sha256sum "$OUTPUT_NAME" > "$OUTPUT_NAME.sha256"
)
chmod 0644 "$package" "$OUTPUT_DIR/$OUTPUT_NAME.sha256"

printf 'Non-writing recovery preflight ready: %s\n' "$ROOT/$package"
