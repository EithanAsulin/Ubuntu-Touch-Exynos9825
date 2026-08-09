#!/bin/sh
# Capture Waydroid framework crash evidence from the LIVE buffer (post-fix).
# Run with sudo. Writes to /home/phablet/waydroid-crash2/.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

dir=/home/phablet/waydroid-crash2
mkdir -p "$dir"
exec >"$dir/capture2.txt" 2>&1

echo '=== timestamp ==='
date -Ins

echo '=== host processes ==='
ps -eo pid,ppid,stat,etime,comm,args | grep -E 'zygote|system_server|bootanimation|waydroidplatform|surfaceflinger' | grep -v grep || true

echo '=== full logcat: last system_server fatal (with stack) ==='
timeout 25 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/logcat -b crash -d -v threadtime 2>/dev/null | tail -120 || true

echo '=== logcat main: SystemServer start + fatal lines ==='
timeout 25 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/logcat -b main -d -v threadtime 2>/dev/null \
  | grep -iE 'SystemServer|StartPackageManagerService|FATAL EXCEPTION IN SYSTEM PROCESS|Abort message|E System|E Zygote|E AndroidRuntime|NPE|NullPointer|Exception|Error reading|Can.t|Unable to' \
  | tail -120 || true

echo '=== properties ==='
for p in sys.boot_completed init.svc.zygote init.svc.bootanim; do
  printf '%s=' "$p"
  timeout 10 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- /system/bin/getprop "$p" || true
done

echo '=== kernel: zygote restart + cgroup + prop errors ==='
dmesg 2>/dev/null | grep -iE 'zygote|createProcessGroup|/acct|cgroup|sys_prop|FATAL' | tail -80 || true

chmod 0644 "$dir/capture2.txt"
echo "=== WROTE $dir/capture2.txt ==="
