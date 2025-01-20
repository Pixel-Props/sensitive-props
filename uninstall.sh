#!/system/bin/busybox sh

MODPATH="${0%/*}"

# Find install-recovery.sh and set permissions back to default
find /vendor/bin /system/bin -name install-recovery.sh -exec chmod 0755 {} \;

# Revert permissions for other files/directories
chmod 644 /proc/cmdline
chmod 644 /proc/net/unix
chmod 755 /system/addon.d
chmod 755 /sdcard/TWRP
