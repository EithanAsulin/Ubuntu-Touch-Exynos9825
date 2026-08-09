#!/bin/sh
# Force Waydroid's Android 11 container to run only the 64-bit zygote.
# Fixes the boot wedged on the 32-bit zygote_secondary (no system_server).
# Run with sudo. Idempotent.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

prop=/var/lib/waydroid/waydroid.prop

systemctl stop waydroid-container.service || true

if grep -q '^ro.zygote=' "$prop"; then
    sed -i 's/^ro.zygote=.*/ro.zygote=zygote64/' "$prop"
else
    printf 'ro.zygote=zygote64\n' >> "$prop"
fi

echo '--- waydroid.prop zygote line ---'
grep '^ro.zygote=' "$prop"

systemctl start waydroid-container.service
sleep 8

echo '--- live container props ---'
lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- sh -c 'getprop ro.zygote; getprop sys.boot_completed'
