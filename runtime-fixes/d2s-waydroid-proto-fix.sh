#!/bin/sh
# Fix Waydroid binder protocol mismatch: the cfg uses aidl3 (Android 13+)
# but the Android 11 system image speaks the classic HIDL/binder protocol.
# This is why services register but system_server can't see them.
# Run with sudo. Idempotent.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

cfg=/var/lib/waydroid/waydroid.cfg

echo '=== before ==='
grep -E 'binder_protocol|service_manager_protocol' "$cfg"

# Android 11 uses the classic binder/HIDL service manager protocol.
sed -i 's/^binder_protocol = .*/binder_protocol = binder/' "$cfg"
sed -i 's/^service_manager_protocol = .*/service_manager_protocol = hidl/' "$cfg"

echo '=== after ==='
grep -E 'binder_protocol|service_manager_protocol' "$cfg"

echo '=== restarting waydroid container ==='
systemctl stop waydroid-container.service 2>/dev/null || true
sleep 2
systemctl start waydroid-container.service 2>/dev/null || true
echo '=== done. Restart Waydroid UI session. ==='
