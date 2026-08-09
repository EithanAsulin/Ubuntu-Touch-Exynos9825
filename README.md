# Ubuntu Touch Device Tree for the Samsung Galaxy Note 10+ (Exynos 9825/N975F)

> Any damage such as bricking or data loss is the responsibility of the user. This port was tested successfully on a clean install and is not recommended for daily use.
This repository contains the device tree for the Samsung Galaxy Note 10+ (Exynos 9825/N975F) running Ubuntu Touch 20.04 (Focal)
> This port is not affiliated with official UBports team nor samsung electronics other than the device itself. Do not blame UBports or samsung electronics for any issues with this port.
> THis was only tested on a samsung d2s (Samsung Galaxy Note 10+ 4G) not a samsung d2x (Samsung Galaxy Note 10+ 5G) and is ONLY meant for exynos 9825 devices.

If you'd like to contribute, please open an issue or submit a pull request it'd be really helpful to get more testing on devices like the d2x (Samsung Galaxy Note 10+ 5G).

## What works:
---
✅ SSH

✅ USB tethering/MTP

✅ Display

✅ Touchscreen

✅ Audio

✅ Hardware acceleration

✅ basic X11 app support

✅ Internal storage

✅ Battery (Charging state, Level)

✅ OpenStore Apps

✅ I/O devices (Mouse, Keyboard tested)

✅ S Pen

✅ 24 Hour test

✅ 7 Day test

❌ Waydroid

❌ Haptics (Do work but cause a bootloop after some times, fails 24 hour test.)

❌ Camera

❌ Weather App

---
## Not tested:
--- 

❌ VoLTE

❌ VoWiFi

❌ Messaging

❌ External storage

---

- **Conclusion:** This device tree is a work in progress, not ready for daily use and isn't recommended. (Due to waydroid)


# How to flash:
***THIS REQUIRES A LINUX HOST, DO NOT TRY ON MACOS, FREEBSD, UNIX, WINDOWS***

- **Disclaimer:** This guide assumes you are using an Ubuntu host with good technical knowledge and have the necessary tools installed. 

To start off, unlock the bootloader and install a custom recovery.
---
Go to the [LineageOS wiki](https://wiki.lineageos.org/devices/d2s/) and follow the instructions to unlock the bootloader and install a custom recovery.

**!!! This WILL VOID YOUR WARRANTY AND DELETE ALL DATA !!!**

Build the sideload-able zip for android recovery
---
```sh
git clone https://github.com/EithanAsulin/Ubuntu-Touch-Exynos9825.git
cd Ubuntu-Touch-Exynos9825
```

Download the vendor image for focal and place it in the right folder
---
- **[Download the vendor image for focal](https://github.com/EithanAsulin/Ubuntu-Touch-Exynos9825/releases/download/vendor-focal/vendor.img)**
- Place the downloaded `vendor.img` in the `images-focal` folder (cp ~/Downloads/vendor.img ./images-focal/)

After cloning, run the following commands to build a sideload-able zip for android recovery
---
```sh
./build.sh -b workdir
./scripts/prepare-focal-ota.sh
./scripts/build-focal-images.sh
./scripts/verify-artifacts.sh
./scripts/make-adb-sideload-zip.sh
```
This should take about ~30 Minutes on a mid-range Linux host.

to Flash run this (only if the build went successfully)
---
It's recommended to use a LineageOS/Evolution X android 16 base ROM before flashing this zip, For this step you must of already flashed atleast a LineageOS/Evolution X recovery image
```sh
sideload-focal/ubuntu-touch-focal-d2s-sideload.zip
```
Do not format data after or before flashing this zip, once it's done just reboot into system.


# Acknowledgements
- UBports `samsung-exynos9820` Halium 12 Adaption
- UBports `samsung-exynos9820` Kernel
- UBports porting tools

# Disclaimer
As a single developer working on this project with near 0 info for the exynos 9825 **Generative AI (Deepseek, Codex) Was used to assist and to speed up research and development.** i understand how people may find this disrespectful with a project like ubuntu touch which focuses on a more human-only approach and felt that this must be mentioned.
