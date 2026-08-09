#!/bin/sh
# Diagnose why android.hardware.vibrator@1.0 never registers in Waydroid,
# blocking system_server and triggering the Watchdog kill. Run with sudo.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

out=/home/phablet/waydroid-vibrator.txt
exec >"$out" 2>&1

echo '=== timestamp ==='
date -Ins

echo '=== vibrator service props ==='
for p in init.svc.vendor.vibrator-1-0 init.svc.vibrator init.svc.android.hardware.vibrator-1-0; do
  printf '%s=' "$p"
  timeout 8 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- /system/bin/getprop "$p" 2>&1 || echo TIMEOUT
done

echo '=== vibrator process in container ==='
timeout 10 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/sh -c 'ps -A | grep -iE "vibrator|hwservicemanager"' 2>&1 || echo FAILED

echo '=== vibrator rc files ==='
timeout 10 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/sh -c 'ls -la /vendor/etc/init/ | grep -i vibr; ls -la /system/etc/init/ | grep -i vibr' 2>&1 || echo FAILED

echo '=== vibrator rc content ==='
timeout 10 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/sh -c 'cat /vendor/etc/init/android.hardware.vibrator@1.0-service.waydroid.rc 2>/dev/null; echo ---; cat /vendor/etc/init/android.hardware.vibrator@1.0-service.rc 2>/dev/null' 2>&1 || echo FAILED

echo '=== logcat vibrator lines ==='
timeout 20 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/logcat -b all -d -v threadtime 2>&1 \
  | grep -iE 'vibrator|IVibrator' | tail -60 || echo FAILED

echo '=== manifest vintf vibrator ==='
timeout 10 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/sh -c 'grep -A3 -B1 -i vibrator /vendor/etc/vintf/manifest.xml 2>/dev/null | head -40' 2>&1 || echo FAILED

chmod 0644 "$out"
echo "=== WROTE $out ==="
