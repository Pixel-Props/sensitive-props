#!/system/bin/busybox sh

MODPATH="${0%/*}" # Get the directory where the script is located

# If MODPATH is empty or is not default modules path, use current path
if [ -z "$MODPATH" ] || ! echo "$MODPATH" | grep -q '/data/adb/modules/'; then
    MODPATH="$(dirname "$(readlink -f "$0")")"
fi

# Using util_functions.sh
[ -f "$MODPATH/util_functions.sh" ] && . "$MODPATH/util_functions.sh" || abort "! util_functions.sh not found!"

# Wait for boot completion
while [ "$(getprop sys.boot_completed)" != 1 ]; do sleep 5; done

# Wait for the device to decrypt (if it's encrypted) when phone is unlocked once.
until [ -d "/sdcard/Android" ]; do sleep 10; done

# Props

# Fix display properties to remove custom ROM references
replace_value_resetprop ro.build.flavor "lineage_" ""
replace_value_resetprop ro.build.flavor "userdebug" "user"
replace_value_resetprop ro.build.display.id "lineage_" ""
replace_value_resetprop ro.build.display.id "userdebug" "user"
replace_value_resetprop ro.build.display.id "dev-keys" "release-keys"
replace_value_resetprop vendor.camera.aux.packagelist "lineageos." ""
replace_value_resetprop ro.build.version.incremental "eng." ""

# Periodically delete LineageOS and EvolutionX props
while true; do
    hexpatch_deleteprop "lineage"
    hexpatch_deleteprop "evolution"
    hexpatch_deleteprop "crdroid"
    hexpatch_deleteprop "crDroid"
    hexpatch_deleteprop "aospa"
    hexpatch_deleteprop "LSPosed"
    hexpatch_deleteprop "aicp"
    hexpatch_deleteprop "arter97"
    hexpatch_deleteprop "blu_spark"
    hexpatch_deleteprop "cyanogenmod"
    hexpatch_deleteprop "deathly"
    hexpatch_deleteprop "elementalx"
    hexpatch_deleteprop "elite"
    hexpatch_deleteprop "franco"
    hexpatch_deleteprop "hadeskernel"
    hexpatch_deleteprop "morokernel"
    hexpatch_deleteprop "noble"
    hexpatch_deleteprop "optimus"
    hexpatch_deleteprop "slimroms"
    hexpatch_deleteprop "sultan"
    hexpatch_deleteprop "aokp"
    hexpatch_deleteprop "bharos"
    hexpatch_deleteprop "calyxos"
    hexpatch_deleteprop "calyxOS"
    hexpatch_deleteprop "divestos"
    hexpatch_deleteprop "emteria.os"
    hexpatch_deleteprop "grapheneos"
    hexpatch_deleteprop "indus"
    hexpatch_deleteprop "iodéos"
    hexpatch_deleteprop "kali"
    hexpatch_deleteprop "nethunter"
    hexpatch_deleteprop "omnirom"
    hexpatch_deleteprop "paranoid"
    hexpatch_deleteprop "replicant"
    hexpatch_deleteprop "resurrection"
    hexpatch_deleteprop "remix"
    hexpatch_deleteprop "pixelexperience"
    hexpatch_deleteprop "shift"
    hexpatch_deleteprop "volla"
    hexpatch_deleteprop "icosa"
    hexpatch_deleteprop "kirisakura"
    hexpatch_deleteprop "infinity"
    hexpatch_deleteprop "Infinity"
    # add more...

    sleep 3600 # Sleep for 1 hour
done &         # Run the loop in the background

# Realme fingerprint fix
check_resetprop ro.boot.flash.locked 1
check_resetprop ro.boot.realmebootstate green
check_resetprop ro.boot.realme.lockstate 1

# Oppo fingerprint fix
check_resetprop ro.boot.vbmeta.device_state locked
check_resetprop vendor.boot.vbmeta.device_state locked

# OnePlus display/fingerprint fix
check_resetprop vendor.boot.verifiedbootstate green
check_resetprop ro.is_ever_orange 0

# OnePlus/Oppo display fingerprint fix on OOS/ColorOS 12+
check_resetprop ro.boot.verifiedbootstate green
check_resetprop ro.boot.veritymode enforcing

# Fix Partition Check Failed using verifiedBootHash
# resetprop -v -n ro.boot.vbmeta.digest $(echo "" | tr '[:upper:]' '[:lower:]' | tr 'o' '0') # Preferably a module/applet could get the value.

# Samsung warranty bit fix
for prop in ro.boot.warranty_bit ro.warranty_bit ro.vendor.boot.warranty_bit ro.vendor.warranty_bit; do
    check_resetprop "$prop" 0
done

# General adjustments

# Process prefixes for build properties
for prefix in bootimage odm odm_dlkm oem product system system_ext vendor vendor_dlkm; do
    check_resetprop ro.${prefix}.build.type user
    check_resetprop ro.${prefix}.keys release-keys
    check_resetprop ro.${prefix}.build.tags release-keys

    # Remove engineering ROM
    replace_value_resetprop ro.${prefix}.build.version.incremental "eng." ""
done

# Maybe reset properties based on conditions (recovery boot mode)
for prop in ro.bootmode ro.boot.bootmode ro.boot.mode vendor.bootmode vendor.boot.bootmode vendor.boot.mode; do
    maybe_resetprop "$prop" recovery unknown
done

# MIUI cross-region flash adjustments
for prop in ro.boot.hwc ro.boot.hwcountry; do
    maybe_resetprop "$prop" CN GLOBAL
done

# SafetyNet/banking app compatibility
check_resetprop net.tethering.noprovisioning true
check_resetprop sys.oem_unlock_allowed 0
check_resetprop ro.oem_unlock_supported 0

# Init.rc adjustment
check_resetprop init.svc.flash_recovery stopped

# Fake encryption status
check_resetprop ro.crypto.state encrypted

# Secure boot and device lock settings
check_resetprop ro.secureboot.devicelock 1
check_resetprop ro.secure 1
check_resetprop ro.secureboot.lockstate locked

# Disable debugging and adb over network
check_resetprop ro.debuggable 0
check_resetprop ro.adb.secure 0

# Native Bridge (could break some features, appdome?)
# deleteprop ro.dalvik.vm.native.bridge

# Adjust API level if necessary for software attestation
[ "$(resetprop -v ro.product.first_api_level)" -ge 33 ] && resetprop -v -n ro.product.first_api_level 32

# File Permissions

# Hiding SELinux | Use toybox to protect *stat* access time reading
[ -f /sys/fs/selinux/enforce ] && [ "$(toybox cat /sys/fs/selinux/enforce)" == "0" ] && {
    set_permissions /sys/fs/selinux/enforce 640
    set_permissions /sys/fs/selinux/policy 440
}

# Find install-recovery.sh and set permissions
find /vendor/bin /system/bin -name install-recovery.sh | while read -r file; do
    set_permissions "$file" 0440
done

# Set permissions for other files/directories
set_permissions /proc/cmdline 0440
set_permissions /proc/net/unix 0440
set_permissions /system/addon.d 0750
set_permissions /sdcard/TWRP 0750

# Comment the entire line containing --delete
# PlayIntegrityFix is still relying on it and it defeats the purpose of using this module.
find /data/adb/modules -type f -name "*.sh" | while read -r file; do
    sed -i -e '/resetprop.*--delete/!b' -e "/^[[:space:]]*#/b" -e "/[[:space:]]*--delete/s/^/#/" "$file" 2>/dev/null
done

# System Settings

# Fix Restrictions on non-SDK interface and disable developer options
for global_setting in hidden_api_policy hidden_api_policy_pre_p_apps hidden_api_policy_p_apps; do # adb_enabled development_settings_enabled tether_dun_required
    settings delete global "$global_setting" >/dev/null 2>&1
done

# Disable untrusted touches
for setting in block_untrusted_touches; do
    for namespace in global system secure; do
        settings put "$namespace" "$setting" 0 >/dev/null 2>&1
    done
done
