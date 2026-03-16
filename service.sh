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

# Check cron status
if [ -f "$MODPATH/disable_cron" ]; then
  # "Always Disable" flag
  _cron_disabled=1
elif [ -f "$MODPATH/disable_cron_temp" ]; then
  # "Disable until Reboot" flag (tmp file)
  rm -f "$MODPATH/disable_cron_temp"
  _cron_disabled=0
else
  # config.prop fallback
  _cron_cfg=$(grep -s '^propscleaner_cron=' "$MODPATH/config.prop" | cut -d= -f2)
  if boolval "$_cron_cfg"; then
    _cron_disabled=0
  else
    _cron_disabled=1
  fi
fi

if ! boolval "$_cron_disabled"; then
  sh $MODPATH/propscleaner.sh &

  [ ! -f $MODPATH/crontabs/root ] && {
    mkdir -p $MODPATH/crontabs
    echo "30 * * * * sh $MODPATH/propscleaner.sh > /dev/null 2>&1 &" | busybox crontab -c $MODPATH/crontabs - # once every 60 minutes
  }

  # Start crond every time service.sh starts
  [ -d $MODPATH/crontabs ] && busybox crond -bc $MODPATH/crontabs -L /dev/null > /dev/null 2>&1 &

  _cron_tag="[✅ Custom ROM spoofing,"
else
  # Stop crond and remove crontab if disabled
  busybox pkill -f "crond -bc $MODPATH/crontabs" 2>/dev/null
  rm -rf "$MODPATH/crontabs"

  if [ -f "$MODPATH/disable_cron" ]; then
    _cron_tag="[❌ Custom ROM spoofing,"
  else
    _cron_tag="[⏸️ Custom ROM spoofing,"
  fi
fi

# Check if resetprop-rs is installed
if [ -x "$MODPATH/resetprop-rs" ]; then
  _rs_tag="✅ resetprop-rs]"
else
  _rs_tag="❌ resetprop-rs]"
fi

# Update module description to reflect current status
set_description "$_cron_tag $_rs_tag"
restore_desc_if_needed

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

# Outdated PlayIntegrity pixelprops fix
getprop | grep -E "pihook|pixelprops|eliteprops|spoof.gms" | sed -E "s/^\[(.*)\]:.*/\1/" | while IFS= read -r prop; do hexpatch_deleteprop "$prop"; done

### General adjustments ###

# Process prefixes for build properties
for prefix in bootimage odm odm_dlkm oem product system system_ext vendor vendor_dlkm; do
  check_resetprop ro.${prefix}.build.type user
  check_resetprop ro.${prefix}.keys release-keys
  check_resetprop ro.${prefix}.build.tags release-keys
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

# ADBD/adb_root status spoofing
check_resetprop init.svc.adbd stopped
hexpatch_deleteprop init.svc.adb_root

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
  settings put "$namespace" "block_untrusted_touches" 2 >/dev/null 2>&1
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

### VBMeta ###

# Set vbmeta verifiedBootHash from file (if present and not empty)
BOOT_HASH_FILE="/data/adb/boot_hash"
if [ -s "$BOOT_HASH_FILE" ] && grep -qE '^[a-f0-9]{64}$' "$BOOT_HASH_FILE"; then
    force_resetprop ro.boot.vbmeta.digest "$(tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' <"$BOOT_HASH_FILE")"
fi

# Fix altered VBMeta
missing_resetprop ro.boot.vbmeta.avb_version 1.2
missing_resetprop ro.boot.vbmeta.hash_alg sha256
force_resetprop ro.boot.vbmeta.device_state locked
force_resetprop ro.boot.vbmeta.invalidate_on_error yes

# Dynamic vbmeta_size -- use partition byte size with A/B slot suffix + multi-path fallback
# Thanks to Enginex0
slot_suffix=$(getprop ro.boot.slot_suffix 2>/dev/null)
VBMETA_SIZE=""
for candidate in \
    "/dev/block/by-name/vbmeta${slot_suffix}" \
    "/dev/block/by-name/vbmeta" \
    "/dev/block/by-name/vbmeta_a" \
    "/dev/block/by-name/vbmeta_b"; do
    if [ -b "$candidate" ]; then
        VBMETA_SIZE=$(blockdev --getsize64 "$candidate" 2>/dev/null)
        [ -n "$VBMETA_SIZE" ] && [ "$VBMETA_SIZE" -gt 0 ] 2>/dev/null && break
        VBMETA_SIZE=""
    fi
done
missing_resetprop "ro.boot.vbmeta.size" "${VBMETA_SIZE:-4096}"

