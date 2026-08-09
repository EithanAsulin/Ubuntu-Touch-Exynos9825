#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHONE="${1:-10.15.19.82}"
KEY="${D2S_SSH_PRIVATE_KEY:-$ROOT/keys/d2s_focal_ed25519}"

ssh_args=(
    -F /dev/null
    -i "$KEY"
    -o ConnectTimeout=10
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
    "phablet@$PHONE"
)

ssh "${ssh_args[@]}" 'sh -se' <<'REMOTE'
set -eu

pass() { printf 'PASS  %s\n' "$1"; }

[ "$(findmnt -n -o FSTYPE /userdata)" = ext4 ]
blocks=$(findmnt -b -n -o SIZE /userdata)
[ "$blocks" -gt 240000000000 ]
[ -f /userdata/.ubuntu-touch-d2s-ext4 ]
pass "persistent ext4 userdata spans the physical partition"

[ "$(systemctl is-active ssh)" = active ]
[ "$(systemctl is-active lightdm)" = active ]
[ "$(getprop init.svc.vendor.hwcomposer-2-2)" = running ]
pid=$(pgrep -n lomiri)
grep -q '/android/vendor/lib64/egl/libGLES_mali.so' "/proc/$pid/maps"
pass "SSH, Lomiri, HWC2, and Mali rendering"

[ "$(systemctl --user is-active pulseaudio.service)" = active ]
[ "$(getprop init.svc.vendor.audio-hal)" = running ]
pactl list short modules | grep -q $'module-droid-card-29\t'
pactl list short sinks | grep -q $'sink.primary-out\tmodule-droid-card.c'
pass "API-29 Samsung speaker path is active"

for service in minimedia mediaextractor mediametrics vendor.media.omx; do
    [ "$(getprop "init.svc.$service")" = running ]
done
[ "$(getprop ubuntu.h264.supported)" = true ]
[ ! -e /usr/lib/aarch64-linux-gnu/gstreamer-1.0/libgsthybris.so ]
[ ! -e /usr/lib/aarch64-linux-gnu/gstreamer-1.0/libgsthybrissink.so ]
pass "Samsung media services and QtWebEngine Hybris decoder gate are enabled"

tries=0
while [ ! -e /userdata/.ubuntu-touch-d2s-waydroid-ready ]; do
    [ "$(systemctl is-failed d2s-waydroid-offline-init.service || true)" != failed ]
    tries=$((tries + 1))
    [ "$tries" -lt 90 ]
    sleep 2
done
waydroid status 2>&1 | grep -vq 'not initialized'
[ -f /userdata/waydroid-images/system.img ]
[ -f /userdata/waydroid-images/vendor.img ]
pass "offline Waydroid ARM64/Halium 11 initialization"

printf '\nAutomatable D2S runtime checks passed. YouTube playback and Waydroid UI still require physical checks.\n'
REMOTE
