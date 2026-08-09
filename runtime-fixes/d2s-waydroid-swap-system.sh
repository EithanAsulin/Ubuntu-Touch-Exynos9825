#!/bin/sh
# Swap Waydroid's system image to Android 11 (lineage-18.1) to match the
# HALIUM_11 vendor. Preserves userdata. Reuses d2s-waydroid-offline-init for
# hash-verified extraction. Must run as root.
set -eu

[ "$(id -u)" -eq 0 ] || {
    echo "Run with sudo." >&2
    exit 1
}

system_zip=${1:-/home/phablet/waydroid-system.zip}
offline_init=${2:-/home/phablet/d2s-waydroid-offline-init.new}
staging=/userdata/waydroid-staging
images=/userdata/waydroid-images

# Expected pinned hashes for Android 11 lineage-18.1 system
expected_zip=2700a68255c234f04453da15bfdaed0b0d30343f3af968cf39a096657d88a625
expected_img=afab4378b6815596f69fd28e1b2261fae0020eb1e440af71a7479f3acb3206c2

[ -f "$system_zip" ] || { echo "missing $system_zip" >&2; exit 1; }
[ -f "$offline_init" ] || { echo "missing $offline_init" >&2; exit 1; }

echo '==> verifying system zip hash'
actual_zip=$(sha256sum "$system_zip" | awk '{print $1}')
[ "$actual_zip" = "$expected_zip" ] || {
    echo "ZIP HASH MISMATCH: got $actual_zip" >&2
    exit 1
}

# The updated offline-init runs directly from /home/phablet (persistent on
# userdata); the /usr/local/sbin copy is on the read-only system image and
# cannot be replaced live.

echo '==> stopping waydroid container'
systemctl stop waydroid-container.service 2>/dev/null || true

echo '==> staging new system zip'
mkdir -p "$staging"
install -m 0644 "$system_zip" "$staging/waydroid-system.zip"

# Force offline-init to re-extract the (new) system image and re-run
# waydroid init. Remove the ready marker so its Condition isn't consulted;
# we invoke it directly anyway.
rm -f /userdata/.ubuntu-touch-d2s-waydroid-ready

echo '==> running offline-init (validates + extracts + waydroid init -f)'
sh "$offline_init"

echo '==> confirming extracted system.img hash'
actual_img=$(sha256sum "$images/system.img" | awk '{print $1}')
[ "$actual_img" = "$expected_img" ] || {
    echo "IMAGE HASH MISMATCH: got $actual_img" >&2
    exit 1
}

echo '==> applying separate-binder config (anbox-* nodes)'
grep -qx 'binder = anbox-binder' /var/lib/waydroid/waydroid.cfg || \
    sed -i 's/^binder = .*/binder = anbox-binder/; s/^vndbinder = .*/vndbinder = anbox-vndbinder/; s/^hwbinder = .*/hwbinder = anbox-hwbinder/' /var/lib/waydroid/waydroid.cfg

grep -qx 'binder = anbox-binder' /var/lib/waydroid/waydroid.cfg
grep -qx 'vndbinder = anbox-vndbinder' /var/lib/waydroid/waydroid.cfg
grep -qx 'hwbinder = anbox-hwbinder' /var/lib/waydroid/waydroid.cfg

echo '==> starting waydroid container'
systemctl start waydroid-container.service

echo '==> DONE. Android 11 system in place, container started.'
