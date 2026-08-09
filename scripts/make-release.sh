#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

RELEASE_NAME="${1:-d2s-focal-$(date +%Y%m%d)}"
RELEASE_DIR="$ROOT/release/$RELEASE_NAME"

./scripts/verify-artifacts.sh

mkdir -p "$RELEASE_DIR"
install -m 0644 images-focal/boot.img "$RELEASE_DIR/boot.img"
install -m 0644 images-focal/ubuntu.img.zst "$RELEASE_DIR/ubuntu.img.zst"
install -m 0600 keys/d2s_focal_ed25519 "$RELEASE_DIR/d2s_focal_ed25519"
install -m 0644 keys/d2s_focal_ed25519.pub "$RELEASE_DIR/d2s_focal_ed25519.pub"
install -m 0644 README.md "$RELEASE_DIR/README.md"
install -m 0644 FLASH.md "$RELEASE_DIR/FLASH.md"

(
    cd "$RELEASE_DIR"
    sha256sum boot.img ubuntu.img.zst d2s_focal_ed25519 d2s_focal_ed25519.pub
) > "$RELEASE_DIR/SHA256SUMS"

sha256sum "$ROOT/images-focal/ubuntu.img" | sed 's#  .*/#  #' > \
    "$RELEASE_DIR/UBUNTU-RAW-SHA256"

ssh-keygen -lf "$RELEASE_DIR/d2s_focal_ed25519.pub" > "$RELEASE_DIR/SSH-FINGERPRINT.txt"
chmod 0644 \
    "$RELEASE_DIR/SHA256SUMS" \
    "$RELEASE_DIR/UBUNTU-RAW-SHA256" \
    "$RELEASE_DIR/SSH-FINGERPRINT.txt"

(cd "$RELEASE_DIR" && sha256sum -c SHA256SUMS)
raw_expected=$(awk '{print $1}' "$RELEASE_DIR/UBUNTU-RAW-SHA256")
raw_actual=$(zstd -dc "$RELEASE_DIR/ubuntu.img.zst" | sha256sum | awk '{print $1}')
test "$raw_actual" = "$raw_expected"
cmp -s README.md "$RELEASE_DIR/README.md"
cmp -s FLASH.md "$RELEASE_DIR/FLASH.md"
printf 'Release ready: %s\n' "$RELEASE_DIR"
