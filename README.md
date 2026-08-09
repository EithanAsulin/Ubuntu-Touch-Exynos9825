# Ubuntu Touch Device Tree for the Samsung Galaxy Note 10+ (Exynos 9825/N975F)

> Any damage such as bricking or data loss is the responsibility of the user. This port was tested successfully on a clean install and is not recommended for daily use.
This repository contains the device tree for the Samsung Galaxy Note 10+ (Exynos 9825/N975F) running Ubuntu Touch 20.04 (Focal)

If you'd like to contribute, please open an issue or submit a pull request it'd be really helpful to get more testing on devices like the d2x (Samsung Galaxy Note 10+ 5G).

## What works:
[X] SSH

[X] USB tethering/MTP

[X] Display

[X] Touchscreen

[X] Audio

[X] Hardware acceleration

[X] basic X11 app support

[X] Internal storage

[X] Battery (Charging state, Level)

[X] OpenStore Apps

[X] I/O devices (Mouse, Keyboard tested)

[X] S Pen

[X] 24 Hour test

[X] 7 Day test

[ ] Waydroid

[ ] Haptics (Do work but cause a bootloop after some times, fails 24 hour test.)

[ ] Camera

[ ] Weather App

## Not tested:
[ ] VoLTE
[ ] VoWiFi
[ ] Messaging
[ ] External storage

- **Conclusion:** This device tree is a work in progress, not ready for daily use and isn't recommended. (Due to waydroid)


# How to flash:
***THIS REQUIRES A LINUX HOST, DO NOT TRY ON MACOS, FREEBSD, UNIX, WINDOWS***
To begin clone the repository
```sh
git clone https://github.com/EithanAsulin/Ubuntu-Touch-Exynos9825.git
cd Ubuntu-Touch-Exynos9825
```

After cloning, run the following commands to build a sideload-able zip for android recovery
```sh
./build.sh -b workdir
./scripts/prepare-focal-ota.sh
./scripts/build-focal-images.sh
./scripts/verify-artifacts.sh
./scripts/make-adb-sideload-zip.sh
```

This should take about ~30 Minutes on a mid-range Linux host.

It's recommended to use a LineageOS/Evolution X android 16 base ROM before flashing this zip, For this step you must of already flashed atleast a LineageOS/Evolution X recovery image.



# Acknowledgements
- UBports `samsung-exynos9820` Halium 12 Adaption
- UBports `samsung-exynos9820` Kernel
- UBports porting tools

# Disclaimer
As a single developer working on this project with near 0 info for the exynos 9825 **Generative AI Was used to assist and to speed up research and development.** i understand how people may find this disrespectful with a project like ubuntu touch which focuses on a more human-only approach and felt that this must be mentioned.
