#!/bin/sh
# Capture what the CURRENT system_server instance blocks on (fresh logcat).
# Run with sudo.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

out=/home/phablet/waydroid-fresh-block.txt
exec >"$out" 2>&1

echo '=== timestamp ==='
date -Ins

echo '=== current system_server pid (host) ==='
pgrep -x system_server || echo 'no system_server on host ns'

echo '=== waydroidplatform pid ==='
pgrep -f waydroidplatform || echo 'no waydroidplatform'

echo '=== fresh logcat: last 60s "Waited one second for" + watchdog ==='
timeout 25 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/logcat -b main -d -v threadtime 2>&1 \
  | grep -iE "Waited one second for|WATCHDOG|Watchdog: .*blocked|has not completed|Killing system process" | tail -40 || echo FAILED

echo '=== last 40 logcat lines mentioning system_server/SystemServer ==='
timeout 25 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/logcat -b main -d -v threadtime 2>&1 \
  | grep -iE "SystemServerTiming|StartService|StartVibrator|Start.*Hal|boot_progress|BOOT_COMPLETED" | tail -60 || echo FAILED

chmod 0644 "$out"
echo "=== WROTE $out ==="
