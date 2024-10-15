#!/system/bin/busybox sh

MODPATH="${0%/*}"

# Find install-recovery.sh and set permissions back to default
find /vendor/bin /system/bin -name install-recovery.sh -exec chmod 0755 {} \;

# Revert permissions for other files/directories
chmod 0644 /proc/cmdline
chmod 0644 /proc/net/unix
chmod 0755 /system/addon.d
chmod 0755 /sdcard/TWRP
