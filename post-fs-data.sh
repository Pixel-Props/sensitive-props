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

# Using util_functions.sh
[ -f "$MODPATH/util_functions.sh" ] && . "$MODPATH/util_functions.sh" || abort "! util_functions.sh not found!"

# Cleanup and replacements (avoiding duplicates with service.sh)
for prop in $(getprop | grep -E "lineage|aosp_|eng.|dev-keys|test-keys|userdebug" | cut -d ":" -f 1 | tr -d '[]'); do
    replace_value_resetprop "$prop" "lineageos." ""
    replace_value_resetprop "$prop" "lineage_" ""
    replace_value_resetprop "$prop" "aosp_" ""
    replace_value_resetprop "$prop" "eng." ""
    replace_value_resetprop "$prop" "dev-keys" "release-keys"
    replace_value_resetprop "$prop" "test-keys" "release-keys"
    replace_value_resetprop "$prop" "userdebug" "user"
done

# Process prefixes (optimized to avoid redundant checks)
for prefix in system vendor system_ext product oem odm vendor_dlkm odm_dlkm bootimage; do
    # Check and reset properties only once per prefix
    check_resetprop "ro.${prefix}.build.tags" release-keys
    check_resetprop "ro.${prefix}.build.type" user

    # Replace values in all relevant properties
    for prop in ro.${prefix}.build.description ro.${prefix}.build.fingerprint ro.product.${prefix}.name; do
        replace_value_resetprop "$prop" "aosp_" ""
    done
done

# Capture boot_hash early before other modules can tamper with it
BOOT_HASH_FILE="/data/adb/boot_hash"
if [ ! -s "$BOOT_HASH_FILE" ]; then
    _digest=$(resetprop -v ro.boot.vbmeta.digest 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
    if echo "$_digest" | grep -qE '^[a-f0-9]{64}$'; then
        echo "$_digest" > "$BOOT_HASH_FILE"
    fi
fi
