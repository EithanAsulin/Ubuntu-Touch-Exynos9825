#!/bin/sh
# Inspect the exact LXC config binder binds and host device inodes, to fix
# the Waydroid vendor HAL registering on the wrong hwbinder domain.
# Run with sudo.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

out=/home/phablet/waydroid-binder-config.txt
exec >"$out" 2>&1

echo '=== timestamp ==='
date -Ins

echo '=== lxc config: ALL binder/host lines ==='
grep -nE 'binder|host_' /var/lib/waydroid/lxc/waydroid/config 2>&1 | head -80

echo '=== config_nodes: binder/host lines ==='
grep -nE 'binder|host_' /var/lib/waydroid/lxc/waydroid/config_nodes 2>&1 | head -80

echo '=== host binder device inodes (full list) ==='
for d in /dev/binder /dev/hwbinder /dev/vndbinder /dev/anbox-binder /dev/anbox-hwbinder /dev/anbox-vndbinder; do
  stat -Lc '%t:%T %i %n' "$d" 2>&1
done

echo '=== container host_hwbinder target (readlink/bind) ==='
timeout 10 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- \
  /system/bin/sh -c 'ls -la /dev/host_hwbinder /dev/hwbinder /dev/binder 2>&1' 2>&1 || echo FAILED

echo '=== rootfs /dev dir entries (source of /dev nodes) ==='
ls -la /var/lib/waydroid/rootfs/dev/ 2>&1 | head -40 || true

chmod 0644 "$out"
echo "=== WROTE $out ==="
