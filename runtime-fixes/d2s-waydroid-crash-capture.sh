#!/bin/sh
# Capture Waydroid Android framework crash evidence: process state + logcat
# + kernel messages. Run with sudo. Writes to /home/phablet/waydroid-crash/.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

dir=/home/phablet/waydroid-crash
mkdir -p "$dir"
exec >"$dir/capture.txt" 2>&1

echo '=== timestamp ==='
date -Ins

echo '=== host processes (zygote/system_server/bootanim) ==='
ps -eo pid,ppid,stat,etime,comm,args | grep -E 'zygote|system_server|bootanimation|waydroidplatform|surfaceflinger|composer' | grep -v grep || true

echo '=== container init pid ==='
lxc-info -P /var/lib/waydroid/lxc -n waydroid -sH || true

echo '=== container logcat: fatal/crash lines ==='
timeout 20 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/logcat -b all -d -v threadtime 2>/dev/null \
  | grep -iE 'fatal|Fatal signal|runtime aborting|Abort message|Watchdog|system_server.*(died|crash)|WatchdogKill|WATCHDOG|avc: denied|SELinux|Permission denied|cannot|could not|Failed to start|Unable to|exception' \
  | tail -200 || true

echo '=== container logcat: system_server start/end ==='
timeout 20 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/logcat -b all -d -v threadtime 2>/dev/null \
  | grep -iE 'SystemServer|SystemServiceManager|StartService|BOOT_PROGRESS|boot_progress|FATAL EXCEPTION IN SYSTEM PROCESS' \
  | tail -120 || true

echo '=== container property states ==='
for p in sys.boot_completed init.svc.bootanim init.svc.zygote init.svc.surfaceflinger; do
  printf '%s=' "$p"
  timeout 10 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- /system/bin/getprop "$p" || true
done

echo '=== kernel dmesg tail (binder/crash) ==='
dmesg 2>/dev/null | tail -200 || true

chmod 0644 "$dir/capture.txt"
echo "=== WROTE $dir/capture.txt ==="
