#!/bin/sh
# Fix Waydroid's vibrator HAL never registering: the container opens BOTH
# /dev/hwbinder (its own domain) AND /dev/host_hwbinder (host domain), and
# blocks registering on host_hwbinder. Point host_hwbinder at the container's
# own binder so both fds share one domain and IVibrator registers.
# Run with sudo.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

cfg=/var/lib/waydroid/lxc/waydroid/config_nodes
echo "=== before ==="
cat "$cfg"

# Replace the host_hwbinder bind (host /dev/hwbinder) with the container's own
# anbox-hwbinder, so the proxy's second fd lands in the same domain.
sed -i 's#lxc.mount.entry = /dev/hwbinder dev/host_hwbinder none bind,create=file,optional 0 0#lxc.mount.entry = /dev/anbox-hwbinder dev/host_hwbinder none bind,create=file,optional 0 0#' "$cfg"

echo "=== after ==="
grep -E 'host_hwbinder|hwbinder' "$cfg"

echo '=== restarting waydroid container ==='
systemctl stop waydroid-container.service 2>/dev/null || true
sleep 3
systemctl start waydroid-container.service 2>/dev/null || true
echo '=== done. restart Waydroid session and check if system_server stays up ==='
