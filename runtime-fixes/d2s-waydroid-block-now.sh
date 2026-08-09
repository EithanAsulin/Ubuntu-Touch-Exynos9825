#!/bin/sh
# Capture the CURRENT system_server block reason (after the vibrator fix).
# Run with sudo.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

out=/home/phablet/waydroid-block-now.txt
exec >"$out" 2>&1

echo '=== timestamp ==='
date -Ins

echo '=== current block: "Waited one second for" ==='
timeout 25 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/logcat -b main -d -v threadtime 2>&1 \
  | grep -iE "Waited one second for" | tail -20 || echo FAILED

echo '=== watchdog blocked handler ==='
timeout 25 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/logcat -b main -d -v threadtime 2>&1 \
  | grep -iE "Watchdog: .*blocked|WATCHDOG|has not completed|HandlerChecker.*not" | tail -20 || echo FAILED

echo '=== registered HALs (lshal) ==='
timeout 15 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/lshal --neat 2>&1 | head -40 || echo FAILED

chmod 0644 "$out"
echo "=== WROTE $out ==="
