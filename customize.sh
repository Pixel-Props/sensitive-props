#!/system/bin/busybox sh

# Define the path of root manager applet bin directories using find and set it to $PATH then export it
if ! command -v busybox >/dev/null 2>&1; then
  TOYS_PATH=$(find "/data/adb" -maxdepth 3 \( -name busybox -o -name ksu_sus \) -exec dirname {} \; | sort -u | tr '\n' ':')
  export PATH="${PATH:+${PATH}:}${TOYS_PATH%:}"
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
  elif [ "$KSU_KERNEL_VER_CODE" -ge 40000 ]; then
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
    # Check for Zygisksu
    if [ -f /data/adb/modules/zygisksu/module.prop ]; then
        USES_ZYGISKSU=1
        ZYGISKSU_VERSION=$(grep versionCode /data/adb/modules/zygisksu/module.prop | sed 's/versionCode=//g')
        ui_print "- Zygisksu version: $ZYGISKSU_VERSION"
    fi
    
    # Check for ReZygisk
    if [ -f /data/adb/modules/rezygisk/module.prop ]; then
        USES_REZYGISK=1
        REZYGISK_VERSION=$(grep versionCode /data/adb/modules/rezygisk/module.prop | sed 's/versionCode=//g')
        ui_print "- ReZygisk version: $REZYGISK_VERSION"
    fi

    # Validate Zygisksu version
    if [ -n "$USES_ZYGISKSU" ]; then
        if [ -z "$ZYGISKSU_VERSION" ] || [ "$ZYGISKSU_VERSION" -lt 106 ]; then
            ui_print "**********************************************"
            ui_print "! Zygisksu version is too old !"
            ui_print "! Please update Zygisksu to latest version !"
            abort "**********************************************"
        fi
    fi
    
    # Validate ReZygisk version
    if [ -n "$USES_REZYGISK" ]; then
        if [ -z "$REZYGISK_VERSION" ] || [ "$REZYGISK_VERSION" -lt 350 ]; then
            ui_print "**********************************************"
            ui_print "! ReZygisk version is too old !"
            ui_print "! Please update ReZygisk to latest version !"
            abort "**********************************************"
        fi
    fi
    
    # Check if neither is installed
    if [[ -z "$USES_ZYGISKSU" ]] && [[ -z "$USES_REZYGISK" ]]; then
        ui_print "**********************************************"
        ui_print "! Neither Zygisk nor ReZygisk found !"
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

if [ "$API" -lt 29 ]; then
  abort "! Only support Android 10+ devices"
fi

# Set Module permissions
set_perm_recursive "$MODPATH" 0 0 0755 0644

# Running the service early using busybox
[ -f "$MODPATH/service.sh" ] && busybox sh "$MODPATH/service.sh" 2>&1

ui_print "? Please uninstall this module before dirty-flashing/updating the ROM."
