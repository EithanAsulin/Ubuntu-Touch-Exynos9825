#!/bin/sh
# Post-full-reset capture: distinguish a real system_server fatal from a
# Watchdog kill, and confirm which host dir backs the container /data.
# Run with sudo.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

dir=/home/phablet/waydroid-crash3
mkdir -p "$dir"
exec >"$dir/capture3.txt" 2>&1

echo '=== timestamp ==='
date -Ins

echo '=== host /data backing dirs ==='
grep -nE 'data' /var/lib/waydroid/lxc/waydroid/config 2>&1 | head -30 || true
echo '--- config_nodes ---'
cat /var/lib/waydroid/lxc/waydroid/config_nodes 2>&1 | head -40 || true
echo '--- waydroid.cfg ---'
grep -E 'host_data_path|images_path|bind|data' /var/lib/waydroid/waydroid.cfg 2>&1 | head -20 || true

echo '=== container /data mount (live) ==='
timeout 15 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- /system/bin/mount 2>&1 | grep -E ' /data |/data ' | head -10 || echo 'mount read failed'

echo '=== watchdog / fatal_count props ==='
for p in framework_watchdog.fatal_count dalvik.vm.dex2oat-threads ro.build.type ro.debuggable; do
  printf '%s=' "$p"
  timeout 10 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- /system/bin/getprop "$p" 2>&1 || true
done

echo '=== crash buffer (last fatal) ==='
timeout 25 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/logcat -b crash -d -v threadtime 2>&1 | tail -100 || true

echo '=== main buffer: watchdog + system_server kill lines ==='
timeout 25 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/logcat -b main -d -v threadtime 2>&1 \
  | grep -iE 'Watchdog|WATCHDOG|Killing|system_server|FATAL|dying|blocked|dex2oat|PackageManager.*dex|slow operation' | tail -120 || true

echo '=== data dir timestamps ==='
ls -la /home/phablet/.local/share/waydroid/data/system/ 2>&1 | head -30 || true
find /home/phablet/.local/share/waydroid/data/system/users -maxdepth 2 -type f 2>&1 | head -30 || true

chmod 0644 "$dir/capture3.txt"
echo "=== WROTE $dir/capture3.txt ==="
