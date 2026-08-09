#!/bin/sh
# Check which binder device Waydroid's vibrator proxy + hwservicemanager use,
# to fix why IVibrator never registers on the container's hwbinder.
# Run with sudo.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

out=/home/phablet/waydroid-vibr-binder.txt
exec >"$out" 2>&1

echo '=== timestamp ==='
date -Ins

echo '=== host /dev binder inodes ==='
stat -Lc '%t:%T %i %n' /dev/binder /dev/hwbinder /dev/vndbinder /dev/anbox-binder /dev/anbox-hwbinder /dev/anbox-vndbinder 2>&1

echo '=== vibrator proxy (6883) fds ==='
for p in 6883 6825 6782; do
  echo "--- pid $p ---"
  ls -l /proc/$p/fd 2>&1 | grep -iE 'binder|/dev/' | head -10
done

echo '=== container /dev binder inodes (via lxc) ==='
lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/sh -c 'stat -c "%t:%T %i %n" /dev/binder /dev/hwbinder /dev/vndbinder /dev/host_hwbinder 2>&1' 2>&1 || echo FAILED

echo '=== container hwservicemanager + vibrator proc ==='
lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/sh -c 'ps -A | grep -iE "hwservicemanager|vibrator"; echo ---; for p in $(pidof hwservicemanager android.hardware.vibrator@1.0-service.waydroid 2>/dev/null); do echo PID=$p; ls -l /proc/$p/fd 2>/dev/null | grep -iE "binder"; done' 2>&1 || echo FAILED

chmod 0644 "$out"
echo "=== WROTE $out ==="
