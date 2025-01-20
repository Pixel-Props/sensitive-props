#!/system/bin/sh

MODPATH="${0%/*}"
MODNAME="${MODPATH##*/}"
MAGISKTMP="$(magisk --path)" || MAGISKTMP=/sbin

if [ "$(magisk -V)" -lt 26302 ] || [ "$(/data/adb/ksud -V)" -lt 10818 ]; then
    touch "$MODPATH/disable"
fi

# Remove Play Services from Magisk DenyList when set to Enforce in normal mode
if magisk --denylist status; then
    magisk --denylist rm com.google.android.gms
else # Check if Shamiko is installed and whitelist feature isn't enabled
    if [ -d "/data/adb/modules/zygisk_shamiko" ] && [ ! -f "/data/adb/shamiko/whitelist" ]; then
        magisk --denylist add com.google.android.gms com.google.android.gms.unstable
    fi
fi

# magiskpolicy --live unsafe mrHuskyDG 😡
# Permission Loophole...
# Thanks to 7lpb3c for pointing it out ❤️

# Using util_functions.sh
[ -f "$MODPATH/util_functions.sh" ] && . "$MODPATH/util_functions.sh" || abort "! util_functions.sh not found!"

# Set vbmeta verifiedBootHash from file (if present and not empty)
BOOT_HASH_FILE="/data/adb/boot.hash"
if [ -s "$BOOT_HASH_FILE" ]; then
    resetprop -v -n ro.boot.vbmeta.digest "$(tr '[:upper:]' '[:lower:]' <"$BOOT_HASH_FILE")"
fi

# Cleanup and replacements (avoiding duplicates with service.sh)
for prop in $(getprop | grep -E "aosp_|test-keys"); do
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
done
