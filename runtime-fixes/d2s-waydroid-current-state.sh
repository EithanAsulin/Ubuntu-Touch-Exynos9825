#!/bin/sh
# Snapshot: current system_server pid + what it's waiting on right now.
# Run with sudo.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

out=/home/phablet/waydroid-current-state.txt
exec >"$out" 2>&1

echo '=== timestamp ==='
date -Ins

echo '=== current system_server pid + etime ==='
ss=$(pgrep -x system_server || true)
echo "ss=$ss"
[ -n "$ss" ] && ps -o pid,etime,stat -p "$ss" 2>&1 || true

echo '=== waydroidplatform ==='
pgrep -f waydroidplatform || echo 'none'

echo '=== which pid is blocking on a HAL right now (last 10 waited lines) ==='
timeout 20 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/logcat -b main -d -v threadtime 2>&1 \
  | grep -iE "Waited one second for" | tail -10 || echo FAILED

echo '=== the pid of the "Waited" (who is blocking?) ==='
timeout 20 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/logcat -b main -d -v threadtime 2>&1 \
  | grep -iE "Waited one second for" | tail -3 | awk '{print $3}' | sort -u || true

echo '=== watchdog blocked handlers (fresh) ==='
timeout 20 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/logcat -b main -d -v threadtime 2>&1 \
  | grep -iE "Watchdog: .*blocked|WATCHDOG|has not completed|Killing system" | tail -20 || echo FAILED

chmod 0644 "$out"
echo "=== WROTE $out ==="
