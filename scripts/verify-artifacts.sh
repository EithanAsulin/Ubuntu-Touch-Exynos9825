#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BOOT_IMAGE="${1:-images-focal/boot.img}"
UBUNTU_IMAGE="${2:-images-focal/ubuntu.img}"
COMPRESSED_IMAGE="${3:-images-focal/ubuntu.img.zst}"
SPARSE_IMAGE="${4:-images-focal/system.img}"
PUBLIC_KEY="${D2S_SSH_PUBLIC_KEY:-keys/d2s_focal_ed25519.pub}"
VENDOR_IMAGE="${5:-images-focal/vendor.img}"
VENDOR_SPARSE_SOURCE="${6:-workdir/downloads/ubports-samsung-exynos9825-h11/vendor.img}"
BOOT_PARTITION_LIMIT=57671680
VENDOR_PARTITION_LIMIT=1331691520

if [ -d "$ROOT/.local/usr/bin" ]; then
    export PATH="$ROOT/.local/usr/bin:$PATH"
    export LD_LIBRARY_PATH="$ROOT/.local/usr/lib/x86_64-linux-gnu/android:$ROOT/.local/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

for file in "$BOOT_IMAGE" "$UBUNTU_IMAGE" "$COMPRESSED_IMAGE" "$SPARSE_IMAGE" "$PUBLIC_KEY" "$VENDOR_IMAGE" "$VENDOR_SPARSE_SOURCE"; do
    if [ ! -f "$file" ]; then
        echo "Missing required artifact: $file" >&2
        exit 1
    fi
done

TMP="$(mktemp -d "$ROOT/workdir/verify.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

pass() {
    printf 'PASS  %s\n' "$1"
}

fs_cat() {
    debugfs -R "cat $1" "$UBUNTU_IMAGE" 2>/dev/null
}

fs_stat() {
    debugfs -R "stat $1" "$UBUNTU_IMAGE" 2>/dev/null
}

boot_size=$(stat -c '%s' "$BOOT_IMAGE")
if [ "$boot_size" -ge "$BOOT_PARTITION_LIMIT" ]; then
    echo "Boot image is too large: $boot_size >= $BOOT_PARTITION_LIMIT" >&2
    exit 1
fi
pass "boot image fits the conservative 55 MiB limit ($boot_size bytes)"

python3 workdir/downloads/android_system_tools_mkbootimg/unpack_bootimg.py \
    --boot_img "$BOOT_IMAGE" --out "$TMP/boot" --format info > "$TMP/boot-info"
grep -qx 'boot magic: ANDROID!' "$TMP/boot-info"
grep -qx 'page size: 2048' "$TMP/boot-info"
grep -qx 'boot image header version: 1' "$TMP/boot-info"
grep -qx 'os version: 12.0.0' "$TMP/boot-info"
grep -qx 'os patch level: 2023-04' "$TMP/boot-info"
grep -qx 'command line args: init=/init systempart=/dev/disk/by-partlabel/system' "$TMP/boot-info"
file "$TMP/boot/kernel" | grep -q 'Linux kernel ARM64 boot executable Image.*4K pages'
cmp -s "$TMP/boot/ramdisk" workdir/downloads/halium-boot-ramdisk.img-merged
base_ramdisk=workdir/downloads/halium-boot-ramdisk.img
base_ramdisk_size=$(stat -c '%s' "$base_ramdisk")
cmp -s -n "$base_ramdisk_size" "$TMP/boot/ramdisk" "$base_ramdisk"
tail -c "+$((base_ramdisk_size + 1))" "$TMP/boot/ramdisk" | \
    gzip -dc 2>/dev/null | \
    cpio -i --quiet --to-stdout scripts/panic/telnet 2>/dev/null > "$TMP/panic-hook"
tail -c "+$((base_ramdisk_size + 1))" "$TMP/boot/ramdisk" | \
    gzip -dc 2>/dev/null | \
    cpio -i --quiet --to-stdout scripts/halium 2>/dev/null > "$TMP/embedded-halium"
tail -c "+$((base_ramdisk_size + 1))" "$TMP/boot/ramdisk" | \
    gzip -dc 2>/dev/null | \
    cpio -i --quiet --to-stdout scripts/init-bottom/d2s-static-rndis \
    2>/dev/null > "$TMP/d2s-static-rndis"
tail -c "+$((base_ramdisk_size + 1))" "$TMP/boot/ramdisk" | \
    gzip -dc 2>/dev/null | \
    cpio -i --quiet --to-stdout scripts/init-bottom/ORDER \
    2>/dev/null > "$TMP/init-bottom-order"
grep -q 'panic network shell disabled' "$TMP/panic-hook"
if grep -Eq 'telnetd|inject_loop|udhcpd' "$TMP/panic-hook"; then
    echo "Initramfs panic hook still exposes a network command channel" >&2
    exit 1
fi
pass "Android boot header, ARM64 kernel, and patched ramdisk"

ikconfig_start=$(grep -abo -m1 'IKCFG_ST' "$TMP/boot/kernel" | cut -d: -f1)
ikconfig_end=$(grep -abo -m1 'IKCFG_ED' "$TMP/boot/kernel" | cut -d: -f1)
test "$ikconfig_end" -gt "$ikconfig_start"
dd if="$TMP/boot/kernel" bs=1 skip=$((ikconfig_start + 8)) \
    count=$((ikconfig_end - ikconfig_start - 8)) status=none | \
    gzip -dc > "$TMP/kernel-config"
for option in \
    'CONFIG_FHANDLE=y' \
    'CONFIG_SECURITY_APPARMOR=y' \
    'CONFIG_SECURITY_APPARMOR_BOOTPARAM_VALUE=1' \
    'CONFIG_DEFAULT_SECURITY_APPARMOR=y' \
    'CONFIG_DEFAULT_SECURITY="apparmor"' \
    'CONFIG_F2FS_FS=y' \
    'CONFIG_F2FS_FS_XATTR=y' \
    'CONFIG_F2FS_FS_SECURITY=y' \
    'CONFIG_F2FS_FS_ENCRYPTION=y' \
    'CONFIG_EXYNOS_DECON_LCD=y' \
    'CONFIG_EXYNOS_DECON_LCD_S6E3HA9=y' \
    'CONFIG_USB_CONFIGFS=y' \
    'CONFIG_USB_CONFIGFS_RNDIS=y' \
    'CONFIG_USB_F_RNDIS=y' \
    'CONFIG_VETH=y' \
    'CONFIG_BRIDGE=y' \
    'CONFIG_BRIDGE_NETFILTER=y' \
    'CONFIG_NET_NS=y' \
    'CONFIG_NF_NAT=y' \
    'CONFIG_IP_NF_NAT=y' \
    'CONFIG_IP_NF_TARGET_MASQUERADE=y' \
    'CONFIG_ANDROID_BINDER_IPC=y' \
    'CONFIG_ASHMEM=y'; do
    grep -qxF "$option" "$TMP/kernel-config"
done
grep -qxF '# CONFIG_RT_GROUP_SCHED is not set' "$TMP/kernel-config"
grep -qxF 'CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder,anbox-binder,anbox-hwbinder,anbox-vndbinder"' \
    "$TMP/kernel-config"
grep -q 'blkid could not identify d2s userdata; assuming F2FS' "$TMP/embedded-halium"
grep -q 'mount -t "$userdata_fstype"' "$TMP/embedded-halium"
grep -q 'using F2FS userdata without ext4 repair/resize' "$TMP/embedded-halium"
grep -q 'userdata mount failed; using ephemeral tmpfs userdata' "$TMP/embedded-halium"
grep -q 'echo "Ubuntu Touch RNDIS" > "$CONFIG/strings/0x409/configuration"' \
    "$TMP/d2s-static-rndis"
grep -q 'ln -s "$GADGET/functions/rndis.usb0" "$CONFIG/f1"' \
    "$TMP/d2s-static-rndis"
grep -q 'echo 10c00000.dwc3 > "$GADGET/UDC"' "$TMP/d2s-static-rndis"
grep -q '/scripts/init-bottom/d2s-static-rndis' "$TMP/init-bottom-order"
pass "AppArmor, D2S display, RNDIS, F2FS, userdata fallback, and Waydroid networking kernel paths"

e2fsck -fn "$UBUNTU_IMAGE" > "$TMP/e2fsck-rootfs" 2>&1
zstd -t "$COMPRESSED_IMAGE" > "$TMP/zstd-test" 2>&1
raw_hash=$(sha256sum "$UBUNTU_IMAGE" | awk '{print $1}')
compressed_raw_hash=$(zstd -dc "$COMPRESSED_IMAGE" | sha256sum | awk '{print $1}')
test "$raw_hash" = "$compressed_raw_hash"
simg_dump "$SPARSE_IMAGE" > "$TMP/sparse-info"
grep -q 'Total of 1310720 4096-byte output blocks' "$TMP/sparse-info"
simg2img "$SPARSE_IMAGE" "$TMP/sparse-raw.img"
cmp -s "$UBUNTU_IMAGE" "$TMP/sparse-raw.img"
pass "ext4 rootfs and exact zstd/sparse round trips"

test "$(sha256sum "$VENDOR_SPARSE_SOURCE" | awk '{print $1}')" = \
    '17d58ebd28e78202fa38ca54250aab76d6c0e9cfb0bab9a7931bd1f312f24860'
cp --reflink=auto "$VENDOR_IMAGE" "$TMP/vendor-raw.img"
test "$(stat -c '%s' "$TMP/vendor-raw.img")" -le "$VENDOR_PARTITION_LIMIT"
e2fsck -fn "$TMP/vendor-raw.img" > "$TMP/e2fsck-vendor" 2>&1
debugfs -R 'cat build.prop' "$TMP/vendor-raw.img" 2>/dev/null | \
    grep -q '^ro.product.vendor.device=d2s$'
debugfs -R 'cat build.prop' "$TMP/vendor-raw.img" 2>/dev/null | \
    grep -q '^ro.vendor.build.version.release=11$'
debugfs -R 'cat etc/init/android.hardware.graphics.composer@2.2-service.rc' \
    "$TMP/vendor-raw.img" 2>/dev/null | \
    grep -q 'interface android.hardware.graphics.composer@2.1::IComposer default'
debugfs -R 'cat etc/init/android.hardware.graphics.composer@2.2-service.rc' \
    "$TMP/vendor-raw.img" 2>/dev/null | grep -q '^on init$'
debugfs -R 'stat bin/hw/android.hardware.graphics.composer@2.2-service' \
    "$TMP/vendor-raw.img" 2>/dev/null | grep -q 'Type: regular'
pass "patched D2S Halium 11 VENDOR fits PIT and starts HWC2 before Mir"

for path in \
    /usr/bin/lomiri \
    /usr/sbin/lomiri-system-compositor \
    /usr/sbin/lightdm \
    /usr/sbin/sshd \
    /usr/sbin/usb_moded \
    /var/lib/lxc/android/android-rootfs.img; do
    fs_stat "$path" | grep -q 'Type: regular'
done
fs_cat /usr/lib/os-release | grep -q '^VERSION_ID="20.04"$'
fs_cat /etc/default/lsc-wrapper.d/10-d2s-framebuffer.conf | \
    grep -q 'setprop ctl.start vendor.hwcomposer-2-2'
fs_cat /etc/default/lsc-wrapper.d/10-d2s-framebuffer.conf | \
    grep -q 'mount --bind /dev/null /vendor/lib64/hw/hwcomposer.exynos9825.so'
if fs_stat /etc/default/lsc-wrapper.d/10-force-hwc2.conf 2>/dev/null | grep -q 'Type:'; then
    echo "Stale forced-HWC2 configuration remains in rootfs" >&2
    exit 1
fi
if fs_stat /usr/lib/systemd/system/lightdm.service.d/wait-for-hwc.conf 2>/dev/null | grep -q 'Type:'; then
    echo "Stale LightDM HWC wait remains in rootfs" >&2
    exit 1
fi
fs_cat /etc/deviceinfo/devices/d2s.yaml | grep -q 'PrettyName: Galaxy Note10+'
pass "Lomiri, LightDM, and ordered D2S HWC2 compatibility chain"

fs_cat /etc/ssh/sshd_config.d/00-d2s-key-only.conf > "$TMP/sshd-key-only.conf"
for directive in \
    'PasswordAuthentication no' \
    'KbdInteractiveAuthentication no' \
    'ChallengeResponseAuthentication no' \
    'PermitEmptyPasswords no' \
    'PubkeyAuthentication yes' \
    'PermitRootLogin no' \
    'AuthenticationMethods publickey'; do
    grep -qxF "$directive" "$TMP/sshd-key-only.conf"
done
debugfs -R "dump /home/phablet/.ssh/authorized_keys $TMP/authorized_keys" \
    "$UBUNTU_IMAGE" >/dev/null 2>&1
cmp -s "$TMP/authorized_keys" "$PUBLIC_KEY"
fs_stat /home/phablet/.ssh/authorized_keys > "$TMP/authorized-key-stat"
grep -q 'Mode:  0600' "$TMP/authorized-key-stat"
grep -q 'User: 32011.*Group: 32011' "$TMP/authorized-key-stat"
debugfs -R 'ls -l /etc/systemd/system/multi-user.target.wants' "$UBUNTU_IMAGE" \
    2>/dev/null | grep -q 'ssh.service'
fs_stat /etc/systemd/system/ssh-property-migration.service | \
    grep -q 'Fast link dest: "/dev/null"'
fs_cat /usr/lib/systemd/system/ssh.service.d/lxc-android-config.conf | \
    grep -q 'Wants=ssh-generate-hostkeys.service'
test "$(fs_cat /etc/default/adbd | tail -n 1)" = 'ADBD_SECURE=1'
for unit in usb-moded.service usb-rescue-mode-off.service usb-tethering.service; do
    fs_stat "/etc/systemd/system/$unit" | grep -q 'Fast link dest: "/dev/null"'
done
fs_cat /usr/local/sbin/d2s-static-rndis-network > "$TMP/d2s-rndis-network"
grep -q 'for candidate in usb0 rndis0' "$TMP/d2s-rndis-network"
grep -q 'ip address replace 10.15.19.82/24 dev "$netdev"' "$TMP/d2s-rndis-network"
grep -q 'touch /var/lib/dhcp/dhcpd.leases' "$TMP/d2s-rndis-network"
grep -q '/usr/sbin/dhcpd -4 -f -q' "$TMP/d2s-rndis-network"
fs_cat /etc/systemd/system/d2s-static-rndis-network.service | \
    grep -q 'ExecStart=/usr/local/sbin/d2s-static-rndis-network'
debugfs -R 'ls -l /etc/systemd/system/multi-user.target.wants' "$UBUNTU_IMAGE" \
    2>/dev/null | grep -q 'd2s-static-rndis-network.service'
fs_cat /etc/systemd/system/d2s-keep-display-on.service > "$TMP/d2s-keep-display-on.service"
grep -q '^Requires=repowerd.service$' "$TMP/d2s-keep-display-on.service"
grep -q '^ExecStart=/usr/sbin/repowerd-cli display on$' "$TMP/d2s-keep-display-on.service"
grep -q '^Restart=always$' "$TMP/d2s-keep-display-on.service"
debugfs -R 'ls -l /etc/systemd/system/multi-user.target.wants' "$UBUNTU_IMAGE" \
    2>/dev/null | grep -q 'd2s-keep-display-on.service'
fs_cat /etc/systemd/user/lomiri-full-greeter.service.d/d2s-compat.conf > \
    "$TMP/d2s-greeter-compat.conf"
grep -q '^Type=simple$' "$TMP/d2s-greeter-compat.conf"
grep -q '^TimeoutStartSec=0$' "$TMP/d2s-greeter-compat.conf"
grep -q '^TimeoutStopSec=5$' "$TMP/d2s-greeter-compat.conf"
fs_cat /etc/systemd/user/maliit-server.service.d/d2s-compat.conf > \
    "$TMP/d2s-maliit-compat.conf"
grep -q '^StartLimitIntervalSec=0$' "$TMP/d2s-maliit-compat.conf"
grep -q "^ExecStartPre=/bin/sh -c 'while \[ ! -S /run/user/32011/mir_socket \]; do sleep 1; done'$" \
    "$TMP/d2s-maliit-compat.conf"
grep -q '^RestartSec=2$' "$TMP/d2s-maliit-compat.conf"
fs_stat /usr/local/bin/d2s-spen-touch-bridge | grep -q 'Mode:  0755'
fs_cat /usr/local/bin/d2s-spen-touch-bridge > "$TMP/d2s-spen-touch-bridge"
grep -q 'D2S S Pen Touch Bridge' "$TMP/d2s-spen-touch-bridge"
grep -q 'ABS_MT_TRACKING_ID' "$TMP/d2s-spen-touch-bridge"
grep -q 'BTN_TOUCH' "$TMP/d2s-spen-touch-bridge"
fs_cat /etc/systemd/user/d2s-spen-touch-bridge.service > \
    "$TMP/d2s-spen-touch-bridge.service"
grep -q '^ExecStart=/usr/local/bin/d2s-spen-touch-bridge /dev/input/event4$' \
    "$TMP/d2s-spen-touch-bridge.service"
grep -q '^Restart=always$' "$TMP/d2s-spen-touch-bridge.service"
debugfs -R 'ls -l /etc/systemd/user/ubuntu-touch-session.target.wants' \
    "$UBUNTU_IMAGE" 2>/dev/null | grep -q 'd2s-spen-touch-bridge.service'
for unit in \
    mtp-server-usb-moded-watcher.service \
    lomiri-location-service-trust-stored.service \
    cameraservice-trust-stored.service \
    ofono-setup.service \
    telephony-service-approver.service \
    telephony-service-indicator.service \
    tone-generator.service \
    audiosystem-passthrough-af.service \
    audiosystem-passthrough-qti.service; do
    fs_stat "/etc/systemd/user/$unit" | grep -q 'Fast link dest: "/dev/null"'
done

for unit in pulseaudio.service pulseaudio.socket; do
    fs_stat "/usr/lib/systemd/user/$unit" | grep -q 'Type: regular'
    if fs_stat "/etc/systemd/user/$unit" 2>/dev/null | grep -q 'Fast link dest: "/dev/null"'; then
        echo "PulseAudio remains masked: $unit" >&2
        exit 1
    fi
done
fs_stat /usr/lib/pulse-13.99.1/modules/module-droid-card-29.so | \
    grep -q 'Type: regular'
fs_stat /usr/lib/pulse-13.99.1/modules/module-droid-hidl.so | \
    grep -q 'Type: regular'
fs_cat /etc/pulse/touch.pa > "$TMP/touch.pa"
grep -q '^load-module module-droid-card-29 module_id=primary voice_virtual_stream=true config=/etc/pulse/d2s-audio-policy.xml$' \
    "$TMP/touch.pa"
grep -q '^load-module module-droid-hidl helper=false$' "$TMP/touch.pa"
if grep -q '^load-module module-droid-discover' "$TMP/touch.pa"; then
    echo "PulseAudio still auto-selects the incompatible droid API" >&2
    exit 1
fi
fs_cat /etc/pulse/d2s-audio-policy.xml > "$TMP/d2s-audio-policy.xml"
test "$(grep -c '<mixPort name="primary-out"' "$TMP/d2s-audio-policy.xml")" = 1
test "$(grep -c '<mixPort .*role="sink"' "$TMP/d2s-audio-policy.xml")" = 0
test "$(grep -c '<mixPort name="\(fast\|deep-buffer\)"' "$TMP/d2s-audio-policy.xml")" = 0
fs_cat /etc/gbinder.conf | grep -q '^ApiLevel = 30$'
fs_cat /etc/init/mount-android.conf > "$TMP/mount-android.conf"
grep -q 'audio.hidl_compat.default.so /vendor/lib64/hw/audio.primary.default.so' \
    "$TMP/mount-android.conf"
grep -q '/opt/halium-overlay/system/etc/init/init.disabled.rc' \
    "$TMP/mount-android.conf"
fs_cat /opt/halium-overlay/system/etc/init/init.disabled.rc > \
    "$TMP/init.disabled.rc"
grep -q '^# service vendor.audio-hal-2-0 ' "$TMP/init.disabled.rc"
grep -q '^# service vendor.audio-hal ' "$TMP/init.disabled.rc"
fs_cat /usr/lib/udev/rules.d/70-exynos7904.rules | \
    grep -q 'KERNEL=="vts_fio_dev".*OWNER="audioserver"'
fs_stat /usr/local/sbin/d2s-android-compat | grep -q 'Mode:  0755'
fs_cat /etc/systemd/system/d2s-android-compat.service > \
    "$TMP/d2s-android-compat.service"
grep -q '^DefaultDependencies=no$' "$TMP/d2s-android-compat.service"
grep -q '^Before=lxc-android-config.service systemd-udev-trigger.service sysinit.target$' \
    "$TMP/d2s-android-compat.service"
grep -q '^ExecStart=/usr/local/sbin/d2s-android-compat$' \
    "$TMP/d2s-android-compat.service"
fs_cat /etc/systemd/system/lxc-android-config.service.d/d2s-compat.conf | \
    grep -q '^Requires=d2s-android-compat.service$'
fs_stat /usr/local/sbin/d2s-android-audio-start | grep -q 'Mode:  0755'
fs_cat /usr/local/sbin/d2s-android-audio-start > "$TMP/d2s-android-media-start"
for service in minimedia mediaextractor mediametrics vendor.media.omx; do
    grep -q "setprop ctl.start $service" "$TMP/d2s-android-media-start"
done
grep -q 'setprop ubuntu.h264.supported true' "$TMP/d2s-android-media-start"
fs_cat /etc/systemd/system/d2s-android-audio.service > \
    "$TMP/d2s-android-audio.service"
grep -q '^Requires=lxc-android-config.service d2s-android-compat.service$' \
    "$TMP/d2s-android-audio.service"
grep -q '^ExecStart=/usr/local/sbin/d2s-android-audio-start$' \
    "$TMP/d2s-android-audio.service"
debugfs -R 'ls -l /etc/systemd/system/multi-user.target.wants' "$UBUNTU_IMAGE" \
    2>/dev/null | grep -q 'd2s-android-audio.service'
fs_cat /etc/systemd/user/pulseaudio.service.d/d2s-audio.conf > \
    "$TMP/d2s-pulseaudio.conf"
grep -q '^ExecStartPre=/usr/local/bin/d2s-wait-android-audio$' \
    "$TMP/d2s-pulseaudio.conf"
for plugin in libgsthybris.so libgsthybrissink.so; do
    if fs_stat "/usr/lib/aarch64-linux-gnu/gstreamer-1.0/$plugin" \
        2>/dev/null | grep -q 'Type:'; then
        echo "Blocking gst-hybris plugin remains in rootfs: $plugin" >&2
        exit 1
    fi
done
fs_cat /usr/lib/aarch64-linux-gnu/qt5/qml/Morph/Web/MorphWebContext.qml > \
    "$TMP/MorphWebContext.qml"
grep -q 'property var userAgentOverrides' "$TMP/MorphWebContext.qml"
grep -q 'function applyUserAgentForUrl' "$TMP/MorphWebContext.qml"
fs_cat /usr/lib/aarch64-linux-gnu/qt5/qml/Morph/Web/MorphWebView.qml > \
    "$TMP/MorphWebView.qml"
grep -q 'targetUrl.indexOf("intent://")' "$TMP/MorphWebView.qml"
fs_cat /usr/lib/aarch64-linux-gnu/qt5/qml/Morph/Web/ua-overrides-mobile.js | \
    grep -q 'Chrome/131.0.0.0'
fs_cat /etc/apparmor.d/local/usr.bin.morph-browser | \
    grep -q 'qtshadercache-'
fs_stat /opt/google/chrome/chrome | grep -q 'Mode:  0755'
fs_stat /opt/google/chrome/WidevineCdm/_platform_specific/linux_arm64/libwidevinecdm.so | \
    grep -q 'Type: regular'
debugfs -R "dump /opt/google/chrome/chrome $TMP/google-chrome" \
    "$UBUNTU_IMAGE" >/dev/null 2>&1
test "$(sha256sum "$TMP/google-chrome" | awk '{print $1}')" = \
    '2810e63c1e8a9eeecee49be53f72367c199cef09b657c183aaab2440a005a27e'
debugfs -R "dump /opt/google/chrome/WidevineCdm/_platform_specific/linux_arm64/libwidevinecdm.so $TMP/libwidevinecdm.so" \
    "$UBUNTU_IMAGE" >/dev/null 2>&1
test "$(sha256sum "$TMP/libwidevinecdm.so" | awk '{print $1}')" = \
    'e43843b7d42c486fc146b3009a87548ece55667e4e117fa1b2c5cdeb2ca35783'
fs_cat /usr/local/bin/d2s-chrome > "$TMP/d2s-chrome"
for flag in \
    '--no-sandbox' \
    '--disable-dev-shm-usage' \
    '--ozone-platform=x11' \
    '--autoplay-policy=no-user-gesture-required'; do
    grep -q -- "$flag" "$TMP/d2s-chrome"
done
grep -q '^Exec=/usr/local/bin/d2s-chrome %U$' \
    < <(fs_cat /usr/share/applications/google-chrome.desktop)
grep -q '^X-Ubuntu-Touch=true$' \
    < <(fs_cat /usr/share/applications/google-chrome.desktop)
fs_stat /usr/bin/google-chrome-stable | \
    grep -q 'Fast link dest: "/usr/local/bin/d2s-chrome"'
fs_stat /usr/bin/gst-inspect-1.0 | grep -q 'Mode:  0755'
fs_stat /usr/local/sbin/d2s-waydroid-offline-init | grep -q 'Mode:  0755'
fs_cat /usr/local/sbin/d2s-waydroid-offline-init > \
    "$TMP/d2s-waydroid-offline-init"
grep -q 'waydroid init -f -i /usr/share/waydroid-extra/images' \
    "$TMP/d2s-waydroid-offline-init"
grep -q 'c4b45fad36bee7c0db8a1d9315a5be0035520c53d3d005a807735ae9b7ee79cf' \
    "$TMP/d2s-waydroid-offline-init"
grep -q '5b48a2771e77ff9085862f58b5c9d852d439d5e57dd38ea33b58381c2b14ca48' \
    "$TMP/d2s-waydroid-offline-init"
grep -q 'Preserve already verified images' "$TMP/d2s-waydroid-offline-init"
fs_cat /usr/lib/waydroid/tools/helpers/drivers.py > "$TMP/waydroid-drivers.py"
test "$(grep -c '^        for node in BINDER_DRIVERS:$' "$TMP/waydroid-drivers.py")" = 2
test "$(grep -c '^        for node in VNDBINDER_DRIVERS:$' "$TMP/waydroid-drivers.py")" = 2
test "$(grep -c '^        for node in HWBINDER_DRIVERS:$' "$TMP/waydroid-drivers.py")" = 2
grep -A4 '^BINDER_DRIVERS = \[$' "$TMP/waydroid-drivers.py" | \
    grep -q '    "anbox-binder"$'
grep -A4 '^VNDBINDER_DRIVERS = \[$' "$TMP/waydroid-drivers.py" | \
    grep -q '    "anbox-vndbinder"$'
grep -A4 '^HWBINDER_DRIVERS = \[$' "$TMP/waydroid-drivers.py" | \
    grep -q '    "anbox-hwbinder"$'
fs_cat /usr/lib/waydroid/data/scripts/waydroid-net.sh > "$TMP/waydroid-net.sh"
! grep -q -- '--checksum-fill' "$TMP/waydroid-net.sh"
fs_cat /etc/systemd/system/d2s-waydroid-offline-init.service | \
    grep -q '^ExecStart=/usr/local/sbin/d2s-waydroid-offline-init$'
debugfs -R 'ls -l /etc/systemd/system/multi-user.target.wants' \
    "$UBUNTU_IMAGE" 2>/dev/null | \
    grep -q 'd2s-waydroid-offline-init.service'
fs_stat /usr/share/waydroid-extra/images | \
    grep -q 'Fast link dest: "/userdata/waydroid-images"'
fs_stat /usr/libexec/hfd-service | grep -q 'Mode:  0755'
debugfs -R 'ls -l /etc/systemd/system/default.target.wants' \
    "$UBUNTU_IMAGE" 2>/dev/null | grep -q 'hfd-service.service'
for service in \
    com.lomiri.TelephonyServiceHandler.service \
    org.freedesktop.Telepathy.Client.TelephonyServiceHandler.service; do
    test "$(fs_cat "/home/phablet/.local/share/dbus-1/services/$service" | tail -n 1)" = \
        'Exec=/bin/false'
done
pass "key-only SSH, stable UI/input, verified Chrome media, and audio/Waydroid integration"

debugfs -R "dump /var/lib/lxc/android/android-rootfs.img $TMP/android-rootfs.img" \
    "$UBUNTU_IMAGE" >/dev/null 2>&1
e2fsck -fn "$TMP/android-rootfs.img" > "$TMP/e2fsck-android" 2>&1
debugfs -R 'stat /system/bin/hwservicemanager' "$TMP/android-rootfs.img" \
    2>/dev/null | grep -q 'Type: regular'
debugfs -R 'stat /system/lib64/hw/audio.hidl_compat.default.so' \
    "$TMP/android-rootfs.img" 2>/dev/null | grep -q 'Type: regular'
debugfs -R 'cat /system/build.prop' "$TMP/android-rootfs.img" \
    2>/dev/null | grep -q '^ro.build.version.release=11$'
test "$(sha256sum "$TMP/android-rootfs.img" | awk '{print $1}')" = \
    '839b6c041a770b8b0d151792f6b84b6ad4a5fc2868d04276c91c5d970db3fb3e'
fs_stat /opt/halium-overlay/vendor/bin/vndservicemanager | grep -q 'Type: regular'
test "$(fs_cat /opt/halium-overlay/vendor/etc/init/vndservicemanager.rc | grep -c '^service vndservicemanager')" = 1
pass "matched Halium Android 11 GSI and D2S vndservicemanager overlay"

cmp -s "$BOOT_IMAGE" workdir/tmp/partitions/boot.img
tar -xJOf out/device_d2s.tar.xz partitions/boot.img > "$TMP/device-boot.img"
cmp -s "$BOOT_IMAGE" "$TMP/device-boot.img"
pass "final boot image matches both build outputs"

sha256sum "$BOOT_IMAGE" "$UBUNTU_IMAGE" "$COMPRESSED_IMAGE" "$SPARSE_IMAGE" "$VENDOR_IMAGE" "$VENDOR_SPARSE_SOURCE"
printf '\nAll D2S Focal artifact checks passed.\n'
