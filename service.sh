#!/system/bin/busybox sh

MODPATH="${0%/*}" # Get the directory where the script is located

# If MODPATH is empty or is not default modules path, use current path
[ -z "$MODPATH" ] || ! echo "$MODPATH" | grep -q '/data/adb/modules/' &&
  MODPATH="$(dirname "$(readlink -f "$0")")"

# Using util_functions.sh
[ -f "$MODPATH/util_functions.sh" ] && . "$MODPATH/util_functions.sh" || abort "! util_functions.sh not found!"

# Wait for boot completion
while [ "$(getprop sys.boot_completed)" != 1 ]; do sleep 2; done

# Wait for the device to decrypt (if it's encrypted) when phone is unlocked once.
until [ -d "/sdcard/Android" ]; do sleep 3; done

### Props ###

# Periodically hexpatch delete custom ROM props
while true; do
  hexpatch_deleteprop "LSPosed" \
    "marketname" "custom.device" "modversion" \
    "lineage" "aospa" "pixelexperience" "evolution" "pixelos" "pixelage" "crdroid" "crDroid" "aospa" \
    "aicp" "arter97" "blu_spark" "cyanogenmod" "deathly" "elementalx" "elite" "franco" "hadeskernel" \
    "morokernel" "noble" "optimus" "slimroms" "sultan" "aokp" "bharos" "calyxos" "calyxOS" "divestos" \
    "emteria.os" "grapheneos" "indus" "iodéos" "kali" "nethunter" "omnirom" "paranoid" "replicant" \
    "resurrection" "rising" "remix" "shift" "volla" "icosa" "kirisakura" "infinity" "Infinity"
  # add more...

  # Wait for 1 hour before the next check.
  sleep 3600
done &

# Fix display properties to remove custom ROM references
replace_value_resetprop ro.build.flavor "lineage_" ""
replace_value_resetprop ro.build.flavor "userdebug" "user"
replace_value_resetprop ro.build.display.id "lineage_" ""
replace_value_resetprop ro.build.display.id "userdebug" "user"
replace_value_resetprop ro.build.display.id "dev-keys" "release-keys"
replace_value_resetprop vendor.camera.aux.packagelist "lineageos." ""
replace_value_resetprop ro.build.version.incremental "eng." ""

# Realme fingerprint fix
check_resetprop ro.boot.flash.locked 1
check_resetprop ro.boot.realme.lockstate 1
check_resetprop ro.boot.realmebootstate green

# Oppo fingerprint fix
check_resetprop ro.boot.vbmeta.device_state locked
check_resetprop vendor.boot.vbmeta.device_state locked

# OnePlus display/fingerprint fix
check_resetprop ro.is_ever_orange 0
check_resetprop vendor.boot.verifiedbootstate green

# OnePlus/Oppo display fingerprint fix on OOS/ColorOS 12+
check_resetprop ro.boot.veritymode enforcing
check_resetprop ro.boot.verifiedbootstate green

# Samsung warranty bit fix
for prop in ro.boot.warranty_bit ro.warranty_bit ro.vendor.boot.warranty_bit ro.vendor.warranty_bit; do
  check_resetprop "$prop" 0
done

### General adjustments ###

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
check_resetprop sys.oem_unlock_allowed 0
check_resetprop ro.oem_unlock_supported 0
check_resetprop net.tethering.noprovisioning true

# Init.rc adjustment
check_resetprop init.svc.flash_recovery stopped

# Fake encryption status
check_resetprop ro.crypto.state encrypted

# Secure boot and device lock settings
check_resetprop ro.secure 1
check_resetprop ro.secureboot.devicelock 1
check_resetprop ro.secureboot.lockstate locked

# Disable debugging and adb over network
check_resetprop ro.force.debuggable 0
check_resetprop ro.debuggable 0
check_resetprop ro.adb.secure 1

# Native Bridge (could break some features, appdome?)
# deleteprop ro.dalvik.vm.native.bridge

# Adjust API level if necessary for software attestation
# [ "$(resetprop -v ro.product.first_api_level)" -eq 33 ] && resetprop -v -n ro.product.first_api_level 32
# [ "$(resetprop -v ro.product.first_api_level)" -ge 34 ] && resetprop -v -n ro.product.first_api_level 34

### System Settings ###

# Fix Restrictions on non-SDK interface and disable developer options
for global_setting in hidden_api_policy hidden_api_policy_pre_p_apps hidden_api_policy_p_apps; do # adb_enabled development_settings_enabled tether_dun_required
  settings delete global "$global_setting" >/dev/null 2>&1
done

# Disable untrusted touches
for namespace in global system secure; do
  settings put "$namespace" "block_untrusted_touches" 0 >/dev/null 2>&1
done

### File Permissions ###

# Hiding SELinux | Use toybox to protect *stat* access time reading
[ -f /sys/fs/selinux/enforce ] && [ "$(toybox cat /sys/fs/selinux/enforce)" == "0" ] && {
  set_permissions /sys/fs/selinux/enforce 640
  set_permissions /sys/fs/selinux/policy 440
}

# Find install-recovery.sh and set permissions
find /vendor/bin /system/bin -name install-recovery.sh | while read -r file; do
  set_permissions "$file" 440
done

# Set permissions for other files/directories
set_permissions /proc/cmdline 440
set_permissions /proc/net/unix 440
set_permissions /system/addon.d 750
set_permissions /sdcard/TWRP 750
