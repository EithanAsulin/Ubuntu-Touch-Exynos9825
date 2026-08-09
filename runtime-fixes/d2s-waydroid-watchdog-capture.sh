#!/bin/sh
# Capture the exact "blocked on" thread that triggers the system_server
# Watchdog kill. Run with sudo. Writes /home/phablet/waydroid-watchdog.txt.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

out=/home/phablet/waydroid-watchdog.txt
exec >"$out" 2>&1

echo '=== timestamp ==='
date -Ins

echo '=== logcat: watchdog blocked/handler lines ==='
timeout 25 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/logcat -b main -d -v threadtime 2>&1 \
  | grep -iE 'Watchdog|watchdog|Blocked|blocked|HandlerChecker|InputDispatcher|Watched|slow operation|has not completed|timeout|WatchdogKill|WATCHDOG' | tail -160

echo '=== logcat: system_server main thread last lines before restart ==='
timeout 25 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/logcat -b main -d -v threadtime 2>&1 \
  | grep -iE 'system_server|SystemServer|SystemServiceManager|BootPhase|StartService|Started service|Unable to start|Failed to start|waited|timeout|missing|Cannot|cannot' | tail -200

chmod 0644 "$out"
echo "=== WROTE $out ==="
