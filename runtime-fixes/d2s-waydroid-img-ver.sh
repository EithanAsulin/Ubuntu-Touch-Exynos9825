#!/bin/sh
# Report the ACTUAL Android version of the installed Waydroid system image.
# Run with sudo.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

out=/home/phablet/waydroid-img-ver.txt
exec >"$out" 2>&1

echo '=== timestamp ==='
date -Ins

echo '=== installed rootfs build.prop ==='
grep -E "ro.build.version.release|ro.build.version.sdk|ro.vndk.version" /var/lib/waydroid/rootfs/system/build.prop 2>&1 | head || echo 'no build.prop'

echo '=== images dir + hashes ==='
ls -la /usr/share/waydroid-extra/images/ 2>&1 | head
sha256sum /usr/share/waydroid-extra/images/system.img /usr/share/waydroid-extra/images/vendor.img 2>&1

echo '=== cfg protocol ==='
grep -E 'binder_protocol|service_manager_protocol|vendor_type' /var/lib/waydroid/waydroid.cfg

echo '=== container runtime version (live) ==='
timeout 10 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/sh -c 'getprop ro.build.version.release; getprop ro.build.version.sdk; getprop ro.vndk.version' 2>&1 || echo 'container not running'

chmod 0644 "$out"
echo "=== WROTE $out ==="
