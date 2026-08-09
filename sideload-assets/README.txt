Ubuntu Touch Focal recovery sideload package for Samsung Galaxy Note10+
SM-N975F (d2s) only.

This package writes the physical SYSTEM, VENDOR, and BOOT partitions. It also
erases USERDATA, creates a kernel-compatible ext4 filesystem across the full
246016901120-byte partition, and stages verified offline Waydroid ARM64/Halium
11 images there. VENDOR is
the pinned Halium 11 D2S image required by Focal's HWC2 display stack; an
Android 16 Composer3 vendor is incompatible. It does not write a PIT or touch
RECOVERY, VBMETA, DTB, DTBO, MODEM, or EFS. After `Install complete`, do not
use recovery Format Data; reboot directly into Ubuntu Touch.

The package is intentionally unsigned because the Evolution X signing private
key is not available. Evolution/Lineage recovery may display a signature
warning; confirm installation only after checking the outer ZIP SHA256 file on
the host.
