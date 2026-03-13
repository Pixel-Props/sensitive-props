#!/system/bin/busybox sh

MODPATH="${0%/*}"

# Find install-recovery.sh and set permissions back to default
find /vendor/bin /system/bin -name install-recovery.sh -exec chmod 0755 {} \;

# Revert permissions for other files/directories
chmod 644 /proc/cmdline
chmod 644 /proc/net/unix
chmod 755 /system/addon.d
chmod 755 /sdcard/TWRP

# Reverse Settings DB changes made by service.sh
for namespace in global system secure; do
  settings delete "$namespace" "block_untrusted_touches" >/dev/null 2>&1
done

# Restore SELinux node permissions
[ -f /sys/fs/selinux/enforce ] && chmod 644 /sys/fs/selinux/enforce
[ -f /sys/fs/selinux/policy ] && chmod 644 /sys/fs/selinux/policy
