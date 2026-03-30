# Ubuntu Touch For The Galaxy Note 10+ d2s (Exynos 9825)
	< PORTED BY DUCK TOOLS (Eithan Asulin) >
	< GitHub : https://github.com/EithanAsulin >
	< Device : Samsung Galaxy Note 10+ Codename D2s >

# IMPORTANT
> ------------------------------------------------------------------------------------------------------------------------------------
If Anything Goes Unexpected And Causes a Brick I Am Not In Fault This Was Tested And Used On The N975F With Mostly Working Features.

!!! DO NOT EXPECT UPDATES THIS IS NOT AN OFFICIAL PORT !!! 
> ------------------------------------------------------------------------------------------------------------------------------------

Hello!
This Is The Finished Result Of Compiling The Exynos 9825 Ubuntu Touch Build.

(Source : https://gitlab.com/ubports/porting/community-ports/android11/samsung-galaxy-note-10-plus/samsung-exynos9825)

# Installation :

# Pre Installation

# 1. Get Fastboot
> sudo apt update && sudo apt install fastboot

# 2. Download Files
> Releases > Ubuntu_Touch_d2s.zip > Extract

# 3. Terminal
> In The Extracted Folder Open a Terminal
 
# 1. Downloads Mode
> sudo ./odin4 -a TWRP.tar

> (This TWRP Is The EternityROM One UI 7 For Improved Stability)

# 2. Enter TWRP (Volume Up + Power 7 Seconds)
> Wipe > Format Data > "yes"

> Reboot > Fastboot (Also Known As Fastbootd)

# 3. Fastboot Flash (sudo apt install fastboot)
> fastboot flash boot boot.img

> fastboot flash system system.img

> fastboot flash vendor vendor.img

# 4. Reboot
> Enjoy You've Succesfully Booted Into Ubuntu Touch 16.04 Xenial

> ------------------------------------------------------------------------------------------------------------------------------------


# OS Info :
> OS : Ubuntu Touch

> Version : 16.04

> Codename : Xenial

> Snapd : No

> Stable : Yes

> Usable : Partial (App Support)



# Bug Fixes :

# Screen Not Responding To Touch?
> Turn It Off For a Second And The Touch Will Come Back

# apt install Fails?
> Ubuntu Touch Locks APT Access And Even If You Have It The Libraries Are Too Old Use Libertine And Deb Files.

