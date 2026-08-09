#!/bin/sh
# FULL reset of Waydroid Android data. Fixes the repeated "leftover Android 13
# data under Android 11" crash cascade (packages.xml, settings_global.xml,
# lineagesettings.db downgrade, ...) by letting Android 11 rebuild /data from
# scratch. Preserves the system/vendor images and the binder+zygote64 config
# (those live outside the data dir). Run with sudo.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

echo '==> stopping waydroid container'
systemctl stop waydroid-container.service || true
sleep 2

data=/home/phablet/.local/share/waydroid/data
[ -d "$data" ] || data=/var/lib/waydroid/data

echo "==> wiping $data (Android /data only; images+config preserved)"
rm -rf "$data"
mkdir -p "$data"

echo '==> confirming images+config preserved:'
ls -d /var/lib/waydroid/waydroid.cfg /var/lib/waydroid/waydroid.prop 2>&1
ls -d /userdata/waydroid-images/system.img /userdata/waydroid-images/vendor.img 2>&1 || true
grep -E '^(binder|vndbinder|hwbinder) =' /var/lib/waydroid/waydroid.cfg 2>&1
grep '^ro.zygote=' /var/lib/waydroid/waydroid.prop 2>&1

echo '==> starting waydroid container'
systemctl start waydroid-container.service || true
echo '==> done. Android 11 will fully reinitialize /data on next session start.'
