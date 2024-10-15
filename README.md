
# Sensitive_Props Mod

This Magisk Module resets sensitive properties to a safe state and tries to bypass SafetyNet / Play Integrity.

## Why this fork exists

This project is a fork of the original [`sensitive_props`](https://github.com/Magisk-Modules-Alt-Repo/sensitive_props) module, which was a collaborative effort by many developers on GitHub. While the original project seems to be inactive, this fork continues its development with significant changes and improvements, primarily based on the `HuskyDG` base.

This fork introduces major changes and enhancements, focusing on efficiency, compatibility, and addressing new SafetyNet/Play Integrity challenges. It aims to provide a reliable solution for bypassing restrictions and enhancing privacy on rooted Android devices.

## Features

* **Resets sensitive properties:** Modifies system properties that may trigger SafetyNet or banking app restrictions.

* **Cleans up custom ROM traces:** Removes references to custom ROMs like LineageOS, EvolutionX, crDroid, etc., from system properties.

* **Device-specific fixes:** Addresses fingerprint issues on Realme, Oppo, and OnePlus devices, and fixes Samsung warranty bit.

* **General system adjustments:** Adjusts build properties, boot mode, and cross-region flash settings for better compatibility.

* **SafetyNet/banking app compatibility:** Applies specific tweaks to improve compatibility with SafetyNet and banking apps.

* **Enhanced privacy:** Hides SELinux status and sets appropriate file permissions to protect user privacy.

* **Disables restrictions:** Disables developer options and untrusted touches to prevent potential security risks.

* **Undetectable property deletion:** Utilizes a `hexpatch` method for deleting properties, making it undetectable by SafetyNet. This method was necessary due to limitations in the `magiskboot` applet, and despite requests for improvement, the maintainer ([`topjohnwu on issue 8315`](https://github.com/topjohnwu/Magisk/issues/8315)) opted not to introduce a proper fix.

## Requirements

* Magisk v26.3+ (26302+) or KernelSU or APatch (latest version)

* Android 11+

## Installation

1. Install the module from the Magisk app or KernelSU app.

2. Reboot your device.

## Notes

* This module is not compatible with older versions of Magisk or KernelSU.

* Please uninstall this module before dirty-flashing/updating the ROM.

* This module may not bypass all SafetyNet checks.

## Troubleshooting

* If you encounter any issues, please try rebooting your device.

* If the issue persists, please create an issue on the GitHub repository with detailed information about your device and the problem you are facing.

## Contributing

* Feel free to submit pull requests with bug fixes or new features.

* Please ensure your code follows the existing code style and includes proper documentation.

## Disclaimer

* Use this module at your own risk.

* I am not responsible for any issues caused by this module.

## Download

* **Releases will be available on [Pling](https://www.pling.com/p/2129780/) and changelogs on [Telegram / PixelProps](https://t.me/PixelProps)**

## Credits

* [T3SL4](https://t.me/T3SL4) on [PixelProps](https://t.me/PixelProps) (me, author of this fork)

* HuskyDG (original base)

* [AarifZ](https://t.me/Aarifmonu)

* All contributors to the original `sensitive_props` project

* All contributors to Magisk and KernelSU
