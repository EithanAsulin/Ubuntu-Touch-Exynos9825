#!/bin/sh
# Clear corrupt Waydroid PackageManager state left by the Android 13 image.
# system_server FATAL-loops on an unterminated packages.xml after the system
# image swap to Android 11. We delete only the settings files so PackageManager
# regenerates them, preserving the anbox-* binder + zygote64 config.
# Run with sudo.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

data=
for p in /home/phablet/.local/share/waydroid/data /var/lib/waydroid/data; do
    if [ -d "$p" ]; then
        data=$p
        break
    fi
done
[ -n "$data" ] || { echo "cannot find waydroid data dir" >&2; exit 1; }
echo "==> container data: $data"

systemctl stop waydroid-container.service || true

rm -f \
    "$data/system/packages.xml" \
    "$data/system/packages.xml.backup" \
    "$data/system/packages-stopped.xml" \
    "$data/system/packages-stopped.xml.backup"

echo '==> removed corrupt package settings:'
ls "$data/system/packages.xml" "$data/system/packages-stopped.xml" 2>&1 || true

systemctl start waydroid-container.service
echo '==> container started; PackageManager will rebuild state on next boot'
