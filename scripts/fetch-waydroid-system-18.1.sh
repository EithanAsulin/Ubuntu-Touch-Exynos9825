#!/bin/bash
# Fetch the Waydroid ARM64 lineage-18.1 (Android 11) system image that pairs
# with the HALIUM_11 vendor already on the phone, and print pinned hashes.
# Usage: ./scripts/fetch-waydroid-system-18.1.sh [OUTDIR]
set -eu

outdir=${1:-workdir/waydroid-images}
mkdir -p "$outdir"

base="https://sourceforge.net/projects/waydroid/files/images/system/lineage/waydroid_arm64/"
dir_html="$outdir/sf-system-dir.html"

echo "==> listing candidate lineage-18.1 system images from SourceForge"
curl -fsSL "$base" -o "$dir_html"
mapfile -t candidates < <(grep -oE 'lineage-18\.1[0-9.-]*VANILLA-waydroid_arm64-system\.zip' "$dir_html" | sort -u)

if [ "${#candidates[@]}" -eq 0 ]; then
    echo "ERROR: no lineage-18.1 VANILLA system.zip found; dump below." >&2
    grep -oE 'lineage-[0-9.]+-[0-9]+-VANILLA-waydroid_arm64-system\.zip' "$dir_html" | sort -u | tail -40
    exit 1
fi

latest="${candidates[-1]}"
echo "==> choosing: $latest"
echo "    (if this is wrong, re-run with a specific filename as second arg)"

dl_url="https://sourceforge.net/projects/waydroid/files/images/system/lineage/waydroid_arm64/$latest/download"
zip_path="$outdir/$latest"
echo "==> downloading $zip_path"
curl -fL --retry 4 --retry-delay 3 -o "$zip_path" "$dl_url"

echo "==> hashes"
echo "ZIP_SHA=$(sha256sum "$zip_path" | awk '{print $1}')"
echo "ZIP_PATH=$zip_path"

echo "==> extracting system.img hash (raw image inside zip)"
unzip -tq "$zip_path"
echo "SYSTEM_IMG_SHA=$(unzip -p "$zip_path" system.img | sha256sum | awk '{print $1}')"

echo "==> done. Paste ZIP_SHA and SYSTEM_IMG_SHA when replying."
