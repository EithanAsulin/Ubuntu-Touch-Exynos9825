#!/bin/sh
# Rebind the CS40L25A haptic driver so it re-runs firmware init now that
# /vendor/firmware is present. Then report vibe state. Run with sudo.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

dev=/sys/bus/i2c/devices/16-0040
drv=/sys/bus/i2c/drivers/cs40l2x

echo '=== before ==='
cat "$dev/name" 2>&1 || true

echo '=== unbind ==='
echo 16-0040 > "$drv/unbind" 2>&1 || echo 'unbind failed (may already be unbound)'
sleep 2

echo '=== rebind ==='
echo 16-0040 > "$drv/bind" 2>&1 || echo 'bind failed'
sleep 3

echo '=== after ==='
ls -la "$dev" 2>&1 | head -20 || echo 'device dir gone after rebind'
for f in "$dev"/vibe_init_success "$dev"/haptic_engine /sys/class/timed_output/vibrator/enable; do
  echo "-- $f"; cat "$f" 2>&1 || true
done

echo '=== dmesg tail cs40 ==='
dmesg 2>/dev/null | grep -iE "cs40|vibe|haptic|cirrus|wmfw|16-0040" | tail -40 || true

echo '=== done ==='
