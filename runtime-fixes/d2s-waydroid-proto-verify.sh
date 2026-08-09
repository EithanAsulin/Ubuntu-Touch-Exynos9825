#!/bin/sh
# Verify whether the Android 11 system image uses HIDL or AIDL service manager.
# Run with sudo.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

out=/home/phablet/waydroid-proto-verify.txt
exec >"$out" 2>&1

echo '=== timestamp ==='
date -Ins

echo '=== container hwservicemanager + servicemanager version ==='
timeout 10 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/sh -c 'getprop ro.build.version.sdk; getprop ro.vndk.version; ls -la /system/bin/hwservicemanager /system/bin/servicemanager 2>&1' 2>&1 || echo FAILED

echo '=== is this AIDL or HIDL? check hwservicemanager strings ==='
timeout 10 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/sh -c 'strings /system/bin/hwservicemanager 2>/dev/null | grep -iE "aidl|hidl|IsAidl|BpHwServiceManager|AServiceManager" | head -20' 2>&1 || echo FAILED

echo '=== system image ro.build.version (from android-rootfs) ==='
debugfs -R 'cat /system/build.prop' /var/lib/waydroid/rootfs/system/build.prop 2>&1 | grep -E "ro.build.version.release|ro.build.version.sdk|ro.vndk.version" || echo 'no build.prop'

chmod 0644 "$out"
echo "=== WROTE $out ==="
