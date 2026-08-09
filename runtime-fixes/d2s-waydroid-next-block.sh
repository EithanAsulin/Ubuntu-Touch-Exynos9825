#!/bin/sh
# Find the NEW thing system_server blocks on (vibrator was fixed; it still
# restarts ~1-2min). Run with sudo.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

out=/home/phablet/waydroid-nextblock.txt
exec >"$out" 2>&1

echo '=== timestamp ==='
date -Ins

echo '=== host haptic state (should be working) ==='
cat /sys/class/timed_output/vibrator/enable 2>&1
cat /sys/class/timed_output/vibrator/motor_type 2>&1

echo '=== waydroid vibrator service + hwservicemanager ==='
timeout 10 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/sh -c 'ps -A | grep -iE "vibrator|hwservicemanager"; echo ---; ls -l /proc/23/fd 2>/dev/null | grep -iE "binder"' 2>&1 || echo FAILED

echo '=== "Waited one second for" (current block) ==='
timeout 25 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/logcat -b main -d -v threadtime 2>&1 \
  | grep -iE "Waited one second for|getService: Trying|Could not find.*default|Watchdog" | tail -40 || echo FAILED

echo '=== watchdog blocked handler (last) ==='
timeout 25 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/logcat -b main -d -v threadtime 2>&1 \
  | grep -iE "Watchdog: .*blocked|WATCHDOG|has not completed|HandlerChecker" | tail -20 || echo FAILED

echo '=== dmesg: watchdog/vibrator/firmware ==='
dmesg 2>/dev/null | grep -iE "cs40|vibe init|watchdog|system_server" | tail -20 || true

chmod 0644 "$out"
echo "=== WROTE $out ==="
