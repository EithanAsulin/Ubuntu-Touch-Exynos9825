#!/bin/sh
# Give Waydroid's system_server much more time before the Watchdog kills it.
# ro.hw_timeout_multiplier is Android's official "slow device" knob: it scales
# the 60s Watchdog timeout (and boot timeouts) by this factor. First boot after
# the /data reset is slow (dexopt + software rendering), and system_server gets
# killed at 60s while waiting on HALs. 10x should let it finish booting.
# Run with sudo. Idempotent.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

prop=/var/lib/waydroid/waydroid.prop

echo '=== stopping waydroid container ==='
systemctl stop waydroid-container.service 2>/dev/null || true
sleep 2

echo '=== setting ro.hw_timeout_multiplier=10 ==='
if grep -q '^ro.hw_timeout_multiplier=' "$prop"; then
    sed -i 's/^ro.hw_timeout_multiplier=.*/ro.hw_timeout_multiplier=10/' "$prop"
else
    printf 'ro.hw_timeout_multiplier=10\n' >> "$prop"
fi
grep '^ro.hw_timeout_multiplier=' "$prop"

echo '=== starting waydroid container ==='
systemctl start waydroid-container.service 2>/dev/null || true

echo '=== done. Restart the Waydroid UI session now. ==='
