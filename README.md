# Sensitive Props Mod

This Magisk/KernelSU/APatch module resets sensitive properties to a safe state and tries to bypass SafetyNet / Play Integrity.

## Why this fork exists

This project is a fork of the original [`sensitive_props`](https://github.com/Magisk-Modules-Alt-Repo/sensitive_props) module, which was a collaborative effort by many developers on GitHub. While the original project seems to be inactive, this fork continues its development with significant changes and improvements, primarily based on the `HuskyDG` base.

This fork introduces major changes and enhancements, focusing on efficiency, compatibility, and addressing new SafetyNet/Play Integrity challenges.

## Features

- **Resets sensitive properties:** Modifies system properties that may trigger SafetyNet or banking app restrictions.
- **Cleans up custom ROM traces:** Removes references to custom ROMs (LineageOS, EvolutionX, crDroid, etc.) from system properties.
- **VBMeta handling:** Dynamic vbmeta size detection with A/B slot support, verified boot hash injection, and VBMeta state correction.
- **Enhanced property deletion:** Optional [resetprop-rs](https://github.com/Enginex0/resetprop-rs) integration for stealth property deletion without magiskboot hexpatch.
- **Device-specific fixes:** Addresses fingerprint issues on Realme, Oppo, and OnePlus devices, and fixes Samsung warranty bit.
- **General system adjustments:** Adjusts build properties, boot mode, and cross-region flash settings.
- **SafetyNet/banking app compatibility:** Specific tweaks to improve compatibility.
- **Enhanced privacy:** Hides SELinux status and sets appropriate file permissions.
- **Block hidden APIs & untrusted touches:** Disables global Android hidden API access and blocks untrusted touches.
- **Undetectable property deletion:** Uses `hexpatch` method or `resetprop-rs` for deleting properties, making it undetectable by SafetyNet.

## Requirements

- Magisk v26.3+ (26302+) or KernelSU (mainline or Next variant) or APatch (latest version)
- Android 11+
- Optional: Volume keys for resetprop-rs installation prompt

## Installation

1. Install the module from the Magisk/KernelSU/APatch app.
2. During installation, you'll be prompted to download **resetprop-rs** (Vol+ to download, Vol- to skip).
3. Reboot your device.

### resetprop-rs (Optional but Recommended)

The module now supports [resetprop-rs](https://github.com/Enginex0/resetprop-rs) by Enginex0, a Rust-based implementation providing:

- **Stealth property deletion** without using magiskboot hexpatch
- **Better detection evasion** for SafetyNet/Play Integrity
- **Faster execution** compared to the hexpatch method

During installation, press **Vol+** within 15 seconds to auto-download resetprop-rs, or **Vol-** to skip. You can also configure this via `config.prop`:
```properties
download_resetprop_rs=true
```
## VBMeta Configuration (Optional)

To set a custom verified boot hash for enhanced Play Integrity API pass:

1. Create `/data/adb/boot_hash` containing your 64-character SHA256 hash (lowercase):
```bash
echo "your64characterlowercasehexhash..." > /data/adb/boot_hash
```
2. Reboot

The module will automatically:
- Set `ro.boot.vbmeta.digest` from your hash file
- Fix `ro.boot.vbmeta.device_state` to `locked`
- Set `ro.boot.vbmeta.avb_version` (1.2) and `ro.boot.vbmeta.hash_alg` (sha256)
- Dynamically detect vbmeta partition size with A/B slot support

## Troubleshooting

- **Installation fails:** Ensure you're installing from the manager app, not recovery.
- **Play Integrity still fails:** Try installing resetprop-rs during installation for better stealth.
- **Boot hash not working:** Ensure `/data/adb/boot_hash` contains exactly 64 hex characters (a-f, 0-9).
- **Module causes bootloop:** Uninstall via recovery or use safe mode.

## Notes

- This module is not compatible with older versions of Magisk or KernelSU.
- Please uninstall this module before dirty-flashing/updating the ROM.
- This module may not bypass all SafetyNet/Play Integrity checks (hardware attestation may still fail).

## Download

- **Releases will be available on [Pling](https://www.pling.com/p/2129780/) and changelogs on [Telegram / PixelProps](https://t.me/PixelProps)**

## Credits

- [**T3SL4**](https://t.me/T3SL4) on [PixelProps](https://t.me/PixelProps) (me, author of this fork)
- **HuskyDG** (original base)
- [**Enginex0**](https://github.com/Enginex0) ([resetprop-rs](https://github.com/Enginex0/resetprop-rs) contributor and VBMeta improvements)
- [**AarifZ**](https://t.me/Aarifmonu)
- All contributors to the original `sensitive_props` project
- All contributors to Magisk, KernelSU, and APatch