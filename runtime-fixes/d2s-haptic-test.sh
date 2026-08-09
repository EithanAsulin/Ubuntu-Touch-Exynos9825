#!/bin/sh
# Safely test the CS40L25A haptic engine after reboot. Writes 1 to enable
# (triggers a brief vibration), then resets to 0. Run with sudo.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

v=/sys/class/timed_output/vibrator

echo '=== pre-state ==='
cat "$v/enable" 2>&1
cat "$v/motor_type" 2>&1 || true
cat "$v/intensity" 2>&1 || true
cat "$v/fw_rev" 2>&1 || true

echo '=== triggering vibration (enable=1) ==='
echo 1 > "$v/enable" 2>&1 || echo 'WRITE ENABLE FAILED'
sleep 1
echo '=== during ==='
cat "$v/enable" 2>&1
sleep 1

echo '=== resetting (enable=0) ==='
echo 0 > "$v/enable" 2>&1 || echo 'WRITE RESET FAILED'
cat "$v/enable" 2>&1

echo '=== done — did the phone buzz? ==='
