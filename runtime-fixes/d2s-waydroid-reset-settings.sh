#!/bin/sh
# Reset Waydroid user-0 settings state so SettingsProvider can regenerate
# it. Fixes: "No fallback file found for: /data/system/users/0/settings_global.xml"
# (system_server crash-loop) after a system-image swap left Android 13 data
# under a fresh Android 11 image. Runs inside the container as root.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

stop_android() {
    systemctl stop waydroid-container.service || true
    sleep 2
}

start_android() {
    systemctl start waydroid-container.service || true
}

echo '==> stopping waydroid container'
stop_android

# The settings live in the container's /data, bind-mounted from the host data dir.
data=/home/phablet/.local/share/waydroid/data
if [ -d /var/lib/waydroid/data ]; then
    data=/var/lib/waydroid/data
fi
echo "==> container data: $data"

users_dir="$data/system/users"
echo '==> current user settings files:'
ls -la "$users_dir/0/" 2>&1 || true

# Remove only the settings state for user 0; Android regenerates it from the
# bundled defaults on next boot. Keep the users dir so no other state is lost.
rm -f "$users_dir/0/settings_global.xml" \
      "$users_dir/0/settings_global.xml.bak" \
      "$users_dir/0/settings_secure.xml" \
      "$users_dir/0/settings_secure.xml.bak" \
      "$users_dir/0/settings_system.xml" \
      "$users_dir/0/settings_system.xml.bak"

echo '==> after removal:'
ls -la "$users_dir/0/" 2>&1 || true

echo '==> starting waydroid container'
start_android
echo '==> done. SettingsProvider will regenerate user-0 settings on next boot.'
