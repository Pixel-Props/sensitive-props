#!/system/bin/sh

MODDIR="${0%/*}"
MODNAME="${MODDIR##*/}"
MAGISKTMP="$(magisk --path)" || MAGISKTMP=/sbin

if [ "$(magisk -V)" -lt 26302 ] || [ "$(/data/adb/ksud -V)" -lt 10818 ]; then
    touch "$MODDIR/disable"
fi

# magiskpolicy --live unsafe mrHuskyDG 😡
# Permission Loophole...
# Thanks to 7lpb3c for pointing it out ❤️

. "$MODDIR/utils.sh"

# Set vbmeta verifiedBootHash from file (if present and not empty)
BOOT_HASH_FILE="/data/adb/boot.hash"
if [ -s "$BOOT_HASH_FILE" ]; then
    resetprop -v -n ro.boot.vbmeta.digest "$(tr '[:upper:]' '[:lower:]' <"$BOOT_HASH_FILE")"
fi

# Cleanup and replacements (avoiding duplicates with service.sh)
for prop in $(getprop | grep -E "aosp_|test-keys"); do # Removed "userdebug" as it's handled in service.sh
    replace_value_resetprop "$prop" "aosp_" ""
    replace_value_resetprop "$prop" "test-keys" "release-keys"
done

# Process prefixes (optimized to avoid redundant checks)
for prefix in system vendor system_ext product oem odm vendor_dlkm odm_dlkm bootimage; do
    # Check and reset properties only once per prefix
    check_resetprop "ro.${prefix}.build.tags" release-keys
    check_resetprop "ro.${prefix}.build.type" user

    # Replace values in all relevant properties
    for prop in ro.${prefix}.build.{description,fingerprint} ro.product.${prefix}.name; do
        replace_value_resetprop "$prop" "aosp_" ""
    done

    # Hmmm
    # check_resetprop ro.${prefix}.build.date.utc $(date +"%s")
done

# check_resetprop ro.build.date.utc $(date +"%s")
# check_resetprop ro.build.version.security_patch $(date +2023-%m-%d)
# check_resetprop ro.vendor.build.security_patch $(date +2023-%m-%d)
