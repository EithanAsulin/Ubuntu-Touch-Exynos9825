#!/bin/sh
# Check the block status AFTER the HIDL protocol fix. Run with sudo.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

out=/home/phablet/waydroid-post-hidl.txt
exec >"$out" 2>&1

echo '=== timestamp ==='
date -Ins

echo '=== current ss pid + etime ==='
ss=$(pgrep -x system_server || true)
echo "ss=$ss"
[ -n "$ss" ] && ps -o pid,etime,stat -p "$ss" || true

echo '=== last "Waited one second for" (what pid, which HAL) ==='
timeout 20 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/logcat -b main -d -v threadtime 2>&1 \
  | grep -iE "Waited one second for" | tail -15 || echo FAILED

echo '=== is vibrator registered now? (lshal) ==='
timeout 15 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/lshal --neat 2>&1 | grep -iE "vibrator|sensors" | head -10 || echo 'none/failed'

echo '=== watchdog blocked lines ==='
timeout 20 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/logcat -b main -d -v threadtime 2>&1 \
  | grep -iE "Watchdog: .*blocked|WATCHDOG|has not completed|Killing system" | tail -15 || echo FAILED

chmod 0644 "$out"
echo "=== WROTE $out ==="
