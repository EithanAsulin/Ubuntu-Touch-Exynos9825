#!/bin/sh
# Test haptic with nonzero intensity (previous test had intensity=0).
# Sets intensity mid-range, triggers enable, then resets intensity to 0.
# Run with sudo.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

v=/sys/class/timed_output/vibrator

echo '=== pre-state ==='
echo "enable=$(cat $v/enable 2>&1)"
echo "intensity=$(cat $v/intensity 2>&1)"
echo "motor_type=$(cat $v/motor_type 2>&1)"

echo '=== setting intensity to 120 ==='
echo 120 > "$v/intensity" 2>&1 || echo 'WRITE INTENSITY FAILED'
echo "intensity now=$(cat $v/intensity 2>&1)"

echo '=== triggering enable=1 ==='
echo 1 > "$v/enable" 2>&1 || echo 'WRITE ENABLE FAILED'
echo "enable during=$(cat $v/enable 2>&1)"
sleep 2

echo '=== resetting intensity to 0 ==='
echo 0 > "$v/intensity" 2>&1 || true
echo "intensity reset=$(cat $v/intensity 2>&1)"
echo "enable final=$(cat $v/enable 2>&1)"

echo '=== done - did the phone buzz this time? ==='
