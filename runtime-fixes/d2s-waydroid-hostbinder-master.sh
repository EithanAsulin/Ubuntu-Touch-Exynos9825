#!/bin/sh
# Fix Waydroid's vibrator HAL registration by repointing host_hwbinder at the
# container's own anbox-hwbinder. The container's vibrator HAL registers
# IVibrator but system_server can't see it because host_hwbinder points at the
# host's /dev/hwbinder (a different binder domain). Remapping it to
# anbox-hwbinder puts both fds on the same domain so registration succeeds.
#
# IMPORTANT: edit the MASTER config_nodes (/var/lib/waydroid/config_nodes),
# NOT the lxc copy (/var/lib/waydroid/lxc/waydroid/config_nodes) which waydroid
# regenerates by `mv` on every container start.
# Run with sudo. Idempotent.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

master=/var/lib/waydroid/config_nodes
lxc=/var/lib/waydroid/lxc/waydroid/config_nodes

echo '=== master before ==='
grep -E 'host_hwbinder' "$master" || echo 'no host_hwbinder line (master missing?)'

# Repoint the host_hwbinder bind from the host's /dev/hwbinder to the
# container's own anbox-hwbinder.
sed -i 's#lxc.mount.entry = /dev/hwbinder dev/host_hwbinder none bind,create=file,optional 0 0#lxc.mount.entry = /dev/anbox-hwbinder dev/host_hwbinder none bind,create=file,optional 0 0#' "$master"

echo '=== master after ==='
grep -E 'host_hwbinder|anbox-hwbinder' "$master"

# Refresh the lxc copy from the master (mirrors what waydroid start does).
mkdir -p "$(dirname "$lxc")"
cp -a "$master" "$lxc"
echo '=== lxc copy refreshed ==='
grep -E 'host_hwbinder|anbox-hwbinder' "$lxc"

echo '=== restarting waydroid container ==='
systemctl stop waydroid-container.service 2>/dev/null || true
sleep 2
systemctl start waydroid-container.service 2>/dev/null || true
echo '=== done. Restart Waydroid UI session and check system_server. ==='
