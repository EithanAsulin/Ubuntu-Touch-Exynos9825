D2S Ubuntu Touch recovery preflight package.

This ZIP runs the same Evolution X updater binary as the full sideload package,
but it does not contain images and does not write, erase, mount, or format any
partition. It checks the d2s and SM-N975F properties, confirms that the physical
SYSTEM/super container is selected, and verifies the live SYSTEM, VENDOR, and
BOOT block device capacities against the downloaded PIT.
