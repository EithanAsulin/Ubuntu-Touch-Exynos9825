#!/bin/sh
# Patch Waydroid's lxc.py so host_hwbinder maps to the container's own
# anbox-hwbinder instead of the host's /dev/hwbinder. On this Halium port the
# host /dev/hwbinder is Ubuntu Touch's binder (no IVibrator), so the container
# vibrator HAL's registration is invisible to system_server -> Watchdog kill
# loop. Mapping host_hwbinder to anbox-hwbinder puts the registration on the
# domain system_server actually queries.
#
# /usr is read-only, so we copy the patched file to /userdata (rw) and
# bind-mount it over the original. Run with sudo.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

orig=/usr/lib/waydroid/tools/helpers/lxc.py
patched=/userdata/waydroid-lxc-patched.py
bind_dst=/usr/lib/waydroid/tools/helpers/lxc.py

echo '=== before ==='
grep -n 'dev/host_hwbinder' "$orig"

cp -a "$orig" "$patched"
# host_hwbinder should map to the container's own HWBINDER_DRIVER (anbox-hwbinder),
# not the host's /dev/hwbinder.
sed -i 's#if not make_entry("/dev/hwbinder", "dev/host_hwbinder"):#if not make_entry("/dev/" + args.HWBINDER_DRIVER, "dev/host_hwbinder"):#' "$patched"

echo '=== after ==='
grep -n 'dev/host_hwbinder' "$patched"

python3 -m py_compile "$patched" || { echo "PY SYNTAX ERROR"; exit 1; }
echo '=== python syntax OK ==='

# Bind-mount the patched file over the read-only original.
mount --bind "$patched" "$bind_dst" || { echo "BIND FAILED"; exit 1; }

echo '=== verify bind ==='
grep -n 'dev/host_hwbinder' "$bind_dst"

echo '=== restarting waydroid container ==='
systemctl stop waydroid-container.service 2>/dev/null || true
sleep 2
systemctl start waydroid-container.service 2>/dev/null || true
echo '=== done. Restart Waydroid UI session and check system_server. ==='
