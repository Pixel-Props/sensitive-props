#!/system/bin/busybox sh

# Define the path of busybox using find and set it to $PATH then export it
if ! command -v busybox >/dev/null 2>&1; then
  BUSYBOX_PATH=$(find "/data/adb" -maxdepth 3 -name busybox -exec dirname {} \; | tr '\n' ':')
  export PATH="$PATH:${BUSYBOX_PATH%:}"
fi

enforce_install_from_app() {
  if ! $BOOTMODE; then
    ui_print "****************************************************"
    ui_print "! Install from Recovery is NOT supported !"
    ui_print "! Please install from Magisk / KernelSU / APatch !"
    abort "****************************************************"
  fi
}

check_magisk_version() {
  ui_print "- Magisk version: $MAGISK_VER_CODE"

  if [ "$MAGISK_VER_CODE" -lt 26302 ]; then
    ui_print "******************************************"
    ui_print "! Please install Magisk v26.3+ (26302+) !"
    abort "******************************************"
  fi
}

check_ksu_version() {
  ui_print "- KernelSU version: $KSU_KERNEL_VER_CODE (kernel) + $KSU_VER_CODE (ksud)"

  if ! [ "$KSU_KERNEL_VER_CODE" ] || [ "$KSU_KERNEL_VER_CODE" -lt 10940 ]; then
    ui_print "**********************************************"
    ui_print "! KernelSU version is too old !"
    ui_print "! Please update KernelSU to latest version !"
    abort "**********************************************"
  elif [ "$KSU_KERNEL_VER_CODE" -ge 20000 ]; then
    ui_print "*****************************************************"
    ui_print "! KernelSU version abnormal !"
    ui_print "! Please integrate KernelSU into your kernel !"
    ui_print "! as submodule instead of copying the source code !"
    abort "*****************************************************"
  fi
  if ! [ "$KSU_VER_CODE" ] || [ "$KSU_VER_CODE" -lt 10942 ]; then
    ui_print "******************************************************"
    ui_print "! ksud version is too old !"
    ui_print "! Please update KernelSU Manager to latest version !"
    abort "******************************************************"
  fi
}

check_zygisksu_version() {
  ZYGISKSU_VERSION=$(grep versionCode /data/adb/modules/zygisksu/module.prop | sed 's/versionCode=//g')
  ui_print "- Zygisksu version: $ZYGISKSU_VERSION"

  if ! [ "$ZYGISKSU_VERSION" ] || [ "$ZYGISKSU_VERSION" -lt 106 ]; then
    ui_print "**********************************************"
    ui_print "! Zygisksu version is too old !"
    ui_print "! Please update Zygisksu to latest version !"
    abort "**********************************************"
  fi
}

enforce_install_from_app
if [ "$KSU" ]; then
  check_ksu_version
  check_zygisksu_version
else
  check_magisk_version
fi

# Check architecture
if [ "$ARCH" != "arm" ] && [ "$ARCH" != "arm64" ] && [ "$ARCH" != "x86" ] && [ "$ARCH" != "x64" ]; then
  abort "! Unsupported platform: $ARCH"
else
  ui_print "- Device platform: $ARCH"
fi

if [ "$API" -lt 30 ]; then
  abort "! Only support Android 11+ devices"
fi

# Set Module permissions
set_perm_recursive "$MODPATH" 0 0 0755 0644

# Running the service early using busybox
[ -f "$MODPATH/service.sh" ] && busybox sh "$MODPATH/service.sh" 2>&1

ui_print "? Please uninstall this module before dirty-flashing/updating the ROM."
