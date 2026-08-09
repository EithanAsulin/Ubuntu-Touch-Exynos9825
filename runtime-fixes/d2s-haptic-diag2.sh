#!/bin/sh
# Diagnose why intensity write fails and find the working haptic trigger path.
# Run with sudo.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

v=/sys/class/timed_output/vibrator

echo '=== intensity write error (verbose) ==='
sh -c 'echo 120 > /sys/class/timed_output/vibrator/intensity' 2>&1 || echo "intensity write rc=$?"
echo "intensity now=$(cat $v/intensity 2>&1)"

echo '=== try haptic_engine path ==='
cat "$v/haptic_engine" 2>&1 || true
sh -c 'echo 1 > /sys/class/timed_output/vibrator/haptic_engine' 2>&1 || echo "haptic_engine write rc=$?"
sleep 1

echo '=== dmesg after writes ==='
dmesg 2>/dev/null | grep -iE "cs40|vibe|haptic|wmfw|intensity|timed_output" | tail -40 || true

echo '=== check enable permissions + try again ==='
ls -la "$v/enable" "$v/intensity" "$v/haptic_engine" 2>&1

echo '=== any user-accessible trigger? event_cmd / cp_trigger ==='
for f in event_cmd cp_trigger_duration cp_trigger_index; do
  echo "-- $f = $(cat "$v/$f" 2>&1)"
done

echo '=== done ==='
