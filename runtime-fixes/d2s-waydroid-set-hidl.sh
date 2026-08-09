#!/bin/sh
# Set Waydroid to the HIDL binder protocol (correct for Android 11 system).
# The config currently has aidl3 (Android 13+) which makes HAL registrations
# invisible to the Android 11 hwservicemanager -> system_server blocks.
# Run with sudo. Idempotent.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

cfg=/var/lib/waydroid/waydroid.cfg

echo '=== before ==='
grep -E 'binder_protocol|service_manager_protocol' "$cfg"

sed -i 's/^binder_protocol = .*/binder_protocol = binder/' "$cfg"
sed -i 's/^service_manager_protocol = .*/service_manager_protocol = hidl/' "$cfg"

echo '=== after ==='
grep -E 'binder_protocol|service_manager_protocol' "$cfg"

echo '=== restarting waydroid container ==='
systemctl stop waydroid-container.service 2>/dev/null || true
sleep 2
systemctl start waydroid-container.service 2>/dev/null || true
echo '=== done. Relaunch Waydroid UI. ==='
