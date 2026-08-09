#!/bin/bash
set -euo pipefail

ADAPTATION_TOOLS_COMMIT="d5838d5c4cf90c7dbece749a451fb14271847dc9"
KERNEL_COMMIT="b9b70b29c94c41365704fcc2ed33be09b4617907"
KERNEL_PATCH="patches/kernel/0001-d2s-enable-fhandle-and-apparmor.patch"

BUILD_DIR="workdir"
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
    if [ "${args[$i]}" = "-b" ] && ((i + 1 < ${#args[@]})); then
        BUILD_DIR="${args[$((i + 1))]}"
        break
    fi
done
BUILD_DIR="$(realpath -m "$BUILD_DIR")"

# Allow the port to build on hosts where the required utilities were unpacked
# into the repository rather than installed system-wide.
if [ -d "$(pwd)/.local/usr/bin" ]; then
    export PATH="$(pwd)/.local/usr/bin:${PATH}"
    export CPATH="$(pwd)/.local/usr/include${CPATH:+:${CPATH}}"
    export LIBRARY_PATH="$(pwd)/.local/usr/lib/x86_64-linux-gnu${LIBRARY_PATH:+:${LIBRARY_PATH}}"
    export LD_LIBRARY_PATH="$(pwd)/.local/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
fi

if [ ! -d build/.git ]; then
    git clone https://gitlab.com/ubports/community-ports/halium-generic-adaptation-build-tools build
fi
if [ "$(git -C build rev-parse HEAD)" != "$ADAPTATION_TOOLS_COMMIT" ]; then
    git -C build checkout --detach "$ADAPTATION_TOOLS_COMMIT"
fi

KERNEL_DIR="$BUILD_DIR/downloads/kernel-samsung-exynos9820"
BASE_RAMDISK="$BUILD_DIR/downloads/halium-boot-ramdisk.img"
if [ ! -d "$KERNEL_DIR/.git" ] || [ ! -f "$BASE_RAMDISK" ]; then
    ./build/build.sh -b "$BUILD_DIR" -c
fi
if ! git -C "$KERNEL_DIR" cat-file -e "$KERNEL_COMMIT^{commit}" 2>/dev/null; then
    git -C "$KERNEL_DIR" fetch --depth 1 origin "$KERNEL_COMMIT"
fi
if [ "$(git -C "$KERNEL_DIR" rev-parse HEAD)" != "$KERNEL_COMMIT" ]; then
    git -C "$KERNEL_DIR" checkout --detach "$KERNEL_COMMIT"
fi

if git -C "$KERNEL_DIR" apply --check "$(pwd)/$KERNEL_PATCH" 2>/dev/null; then
    git -C "$KERNEL_DIR" apply "$(pwd)/$KERNEL_PATCH"
elif ! git -C "$KERNEL_DIR" apply --reverse --check "$(pwd)/$KERNEL_PATCH" 2>/dev/null; then
    echo "Kernel tree is neither clean nor patched as expected: $KERNEL_DIR" >&2
    exit 1
fi

./scripts/prepare-ramdisk-overlay.sh "$BASE_RAMDISK" "$KERNEL_DIR"

exec ./build/build.sh "$@"
