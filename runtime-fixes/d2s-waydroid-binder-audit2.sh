#!/bin/sh
set -u

[ "$(id -u)" -eq 0 ] || {
    echo "Run this helper with sudo." >&2
    exit 1
}

out=/home/phablet/d2s-waydroid-binder-audit2.txt
exec >"$out" 2>&1

echo '=== timestamp ==='
date -Ins

echo '=== container state (bounded) ==='
lxc-info -P /var/lib/waydroid/lxc -n waydroid -sH 2>&1 || true

echo '=== host binder devices ==='
stat -Lc '%t:%T inode=%i mode=%a %n' \
    /dev/binder /dev/hwbinder /dev/vndbinder \
    /dev/anbox-binder /dev/anbox-hwbinder /dev/anbox-vndbinder || true

echo '=== container binder devices (bounded) ==='
timeout 15 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
    /system/bin/stat -c '%t:%T inode=%i mode=%a %n' \
    /dev/binder /dev/hwbinder /dev/vndbinder /dev/host_hwbinder 2>&1 || echo 'lxc-attach stat TIMED OUT / FAILED'

echo '=== container /dev/binder symlink state (bounded) ==='
timeout 15 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
    /system/bin/sh -c 'ls -la /dev/ | grep -E "binder" ; readlink -f /dev/hwbinder /dev/host_hwbinder 2>&1' 2>&1 || echo 'lxc-attach ls TIMED OUT / FAILED'

echo '=== properties (bounded) ==='
for prop in sys.boot_completed init.svc.bootanim init.svc.vendor.vibrator-1-0 init.svc.vendor.sensors-hal-1-0; do
    printf '%s=' "$prop"
    timeout 15 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- /system/bin/getprop "$prop" 2>&1 || echo ' TIMEOUT/FAILED'
done

echo '=== host hwservicemanager processes ==='
ps -eo pid,ppid,user,stat,comm,args | grep -E 'hwservicemanager|vndservicemanager|servicemanager' | grep -v grep || true

echo '=== host-side binder fds for waydroid hw/vnd/servicemanagers ==='
for name in hwservicemanager vndservicemanager servicemanager; do
    for pid in $(pgrep -f "$name" || true); do
        echo "--- $name pid=$pid ---"
        ls -l "/proc/$pid/fd" 2>&1 | grep -E 'binder' || true
    done
done

echo '=== waydroid cfg binder lines ==='
grep -E '^(binder|vndbinder|hwbinder) =' /var/lib/waydroid/waydroid.cfg || true

echo '=== lxc config binder mounts ==='
grep -nE 'binder' /var/lib/waydroid/lxc/waydroid/config /var/lib/waydroid/lxc/waydroid/config_nodes 2>/dev/null || true

chmod 0644 "$out"
echo "Wrote $out" >/dev/console 2>/dev/null || true
