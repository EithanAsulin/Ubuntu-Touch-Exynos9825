#!/bin/sh
# See why container vibrator (pid 77) never registers IVibrator/default on the
# container hwbinder even though it's wired to anbox-hwbinder. Run with sudo.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

out=/home/phablet/waydroid-vibr-reg.txt
exec >"$out" 2>&1

echo '=== timestamp ==='
date -Ins

echo '=== container vibrator (77) logcat lines ==='
timeout 20 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/logcat -b all -d -v threadtime 2>&1 \
  | grep -iE 'vibrator|IVibrator|registerAsService|init.*77|FATAL|ERROR.*77|died' | tail -60 || echo FAILED

echo '=== vibrator process state (container) ==='
timeout 10 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/sh -c 'cat /proc/77/status | grep -E "Name|State|Threads"; echo ---; cat /proc/77/wchan' 2>&1 || echo FAILED

echo '=== does container have android.hardware.vibrator manifest? ==='
timeout 10 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/sh -c 'grep -A4 -i vibrator /vendor/etc/vintf/manifest.xml 2>/dev/null | head -20' 2>&1 || echo FAILED

echo '=== which hwbinder has IVibrator registered? (lshal) ==='
timeout 15 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/lshal 2>&1 | grep -iE 'vibrator' | head -10 || echo 'lshal failed/no vibrator'

chmod 0644 "$out"
echo "=== WROTE $out ==="
