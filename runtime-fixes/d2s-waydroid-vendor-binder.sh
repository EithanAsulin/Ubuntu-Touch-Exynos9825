#!/bin/sh
# Inspect how the Waydroid vendor image wires binder devices, to fix the
# vibrator HAL registering on host_hwbinder (wrong domain). Run with sudo.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

out=/home/phablet/waydroid-vendor-binder.txt
exec >"$out" 2>&1

echo '=== timestamp ==='
date -Ins

echo '=== rootfs /dev binder setup ==='
ls -la /var/lib/waydroid/rootfs/dev/ 2>&1 | grep -iE 'binder|host' || true

echo '=== lxc config: binder entries ==='
grep -nE 'binder|host_hwbinder|anbox' /var/lib/waydroid/lxc/waydroid/config 2>&1 | head -60 || true

echo '=== vendor bin hwbinder/host_hwbinder references ==='
timeout 12 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/sh -c 'ls -la /vendor/bin/hw/ | grep -i vibr; echo ---; strings /vendor/bin/hw/android.hardware.vibrator@1.0-service.waydroid 2>/dev/null | grep -iE "hwbinder|host_hwbinder|binder" | head -30' 2>&1 || echo FAILED

echo '=== vendor libhybris bindings ==='
timeout 12 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/sh -c 'ls -la /vendor/lib64/ /vendor/lib/ 2>/dev/null | grep -iE "hybris|hardware"; echo ---; find /vendor -maxdepth 3 -name "*hybris*" 2>/dev/null' 2>&1 || echo FAILED

echo '=== how host_hwbinder is created in container ==='
timeout 10 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/sh -c 'stat -c "%n %t:%T %i" /dev/host_hwbinder /dev/hwbinder; echo ---; cat /proc/mounts | grep -iE "binder|host"' 2>&1 || echo FAILED

chmod 0644 "$out"
echo "=== WROTE $out ==="
