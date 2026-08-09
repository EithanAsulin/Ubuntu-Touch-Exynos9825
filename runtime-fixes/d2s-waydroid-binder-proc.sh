#!/bin/sh
# Check which binder device Waydroid's hwservicemanager/vibrator use, vs
# the container's configured binder. Run with sudo.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

out=/home/phablet/waydroid-binder-proc.txt
exec >"$out" 2>&1

echo '=== timestamp ==='
date -Ins

echo '=== host binder device inodes ==='
stat -Lc '%t:%T %i %n' /dev/anbox-binder /dev/anbox-hwbinder /dev/anbox-vndbinder 2>&1

echo '=== container /dev binder symlinks + inodes ==='
timeout 12 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/sh -c 'ls -la /dev/ | grep -E "binder"; echo ---; stat -c "%t:%T %i %n" /dev/binder /dev/hwbinder /dev/vndbinder /dev/host_hwbinder /dev/host_vndbinder /dev/host_binder 2>&1' 2>&1 || echo FAILED

echo '=== container hwservicemanager binder fd ==='
for pid in $(timeout 12 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- /system/bin/sh -c 'pidof hwservicemanager' 2>/dev/null || true); do
  echo "--- hwservicemanager pid=$pid ---"
  timeout 12 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
    /system/bin/sh -c 'ls -l /proc/'"$pid"'/fd 2>/dev/null | grep -iE "binder|/dev"' 2>&1 || true
done

echo '=== container vibrator service binder fd ==='
for pid in $(timeout 12 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- /system/bin/sh -c 'pidof android.hardware.vibrator@1.0-service.waydroid' 2>/dev/null || true); do
  echo "--- vibrator pid=$pid ---"
  timeout 12 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
    /system/bin/sh -c 'ls -l /proc/'"$pid"'/fd 2>/dev/null | grep -iE "binder|/dev"' 2>&1 || true
done

echo '=== container hwbinder property ==='
timeout 8 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- /system/bin/getprop ro.hardware.hwservicemanager.hwbinder 2>&1 || true
timeout 8 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- /system/bin/getprop ro.vndk.lite 2>&1 || true

chmod 0644 "$out"
echo "=== WROTE $out ==="
