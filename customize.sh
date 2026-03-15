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
  # Handle empty variables gracefully
  KSU_KERNEL_VER_CODE=${KSU_KERNEL_VER_CODE:-0}
  KSU_VER_CODE=${KSU_VER_CODE:-0}
  
  ui_print "- KernelSU version: $KSU_KERNEL_VER_CODE (kernel) + $KSU_VER_CODE (ksud)"

  # KernelSU Next detection (version 32000+ indicates Next, mainline is ~10000-12000)
  if [ "$KSU_KERNEL_VER_CODE" -ge 32000 ] && [ "$KSU_KERNEL_VER_CODE" -lt 40000 ]; then
    ui_print "- Detected KernelSU Next variant"
    if [ "$KSU_KERNEL_VER_CODE" -lt 32000 ] || [ "$KSU_VER_CODE" -lt 32000 ]; then
      ui_print "**********************************************"
      ui_print "! KernelSU Next version is too old !"
      abort "**********************************************"
    fi
    # Skip mainline checks for KernelSU Next
    return 0
  fi

  # Mainline KernelSU checks
  if [ "$KSU_KERNEL_VER_CODE" -lt 10940 ]; then
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
  
  if [ "$KSU_VER_CODE" -lt 10942 ]; then
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
  # check_zygisksu_version
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

# Using util_functions.sh
[ -f "$MODPATH/util_functions.sh" ] && . "$MODPATH/util_functions.sh" || abort "! util_functions.sh not found!"

# Periodic propscleaner cron toggle
_cron_cfg=$(grep -s '^propscleaner_cron=' "$MODPATH/config.prop" | cut -d= -f2)

ui_print ""
ui_print "- Enable periodic Custom ROMs props spoofing?"
ui_print "  Vol+ = Enable | Vol- = Disable (15s timeout)"

vol_key_wait 15

CRON_ENABLED=""
case "$VOL_RESULT" in
  up)   CRON_ENABLED=true ;;
  down) CRON_ENABLED=false ;;
esac

# Timeout — fall back to config.prop
if [ -z "$CRON_ENABLED" ]; then
  if boolval "$_cron_cfg"; then
    CRON_ENABLED=true
  else
    CRON_ENABLED=false
  fi
fi

if boolval "$CRON_ENABLED"; then
  ui_print "- Custom ROM spoofing enabled"
else
  ui_print "- Custom ROM spoofing disabled"
fi

# Persist into config.prop and manage flag file
if grep -q '^propscleaner_cron=' "$MODPATH/config.prop" 2>/dev/null; then
  sed -i "s|^propscleaner_cron=.*|propscleaner_cron=$CRON_ENABLED|" "$MODPATH/config.prop"
else
  echo "propscleaner_cron=$CRON_ENABLED" >> "$MODPATH/config.prop"
fi

if boolval "$CRON_ENABLED"; then
  rm -f "$MODPATH/disable_cron" "$MODPATH/disable_cron_temp"
else
  touch "$MODPATH/disable_cron"
fi

# Optional resetprop-rs download
RESETPROP_RS_URL="https://github.com/Enginex0/resetprop-rs/releases/latest/download"
case "$ARCH" in
  arm64) RESETPROP_RS_ASSET="resetprop-arm64-v8a" ;;
  arm)   RESETPROP_RS_ASSET="resetprop-armeabi-v7a" ;;
  *)     RESETPROP_RS_ASSET="" ;;
esac

if [ -n "$RESETPROP_RS_ASSET" ]; then
  # Read config.prop preference
  _cfg_val=$(grep -s '^download_resetprop_rs=' "$MODPATH/config.prop" | cut -d= -f2)

  ui_print "- Download resetprop-rs for enhanced stealth hexpatch?"
  ui_print "  Vol+ = Download | Vol- = Skip (15s timeout)"

  vol_key_wait 15

  DO_DOWNLOAD=""
  case "$VOL_RESULT" in
    up)   DO_DOWNLOAD=true ;;
    down) DO_DOWNLOAD=false ;;
  esac

  # Timeout — fall back to config.prop
  if [ -z "$DO_DOWNLOAD" ]; then
    if boolval "$_cfg_val"; then
      DO_DOWNLOAD=true
    else
      DO_DOWNLOAD=false
    fi
  fi

  if boolval "$DO_DOWNLOAD"; then
    ui_print "- Downloading resetprop-rs ($RESETPROP_RS_ASSET)..."
    _dl_ok=false
    if wget -qO "$MODPATH/resetprop-rs" "$RESETPROP_RS_URL/$RESETPROP_RS_ASSET" 2>/dev/null; then
      _dl_ok=true
    elif curl -sLo "$MODPATH/resetprop-rs" "$RESETPROP_RS_URL/$RESETPROP_RS_ASSET" 2>/dev/null; then
      _dl_ok=true
    fi

    if boolval "$_dl_ok"; then
      chmod 755 "$MODPATH/resetprop-rs"
      if "$MODPATH/resetprop-rs" -h >/dev/null 2>&1; then
        ui_print "- resetprop-rs installed successfully"
      else
        ui_print "! resetprop-rs binary failed smoke test, removing"
        rm -f "$MODPATH/resetprop-rs"
      fi
    else
      ui_print "! Download failed, falling back to built-in hexpatch"
      rm -f "$MODPATH/resetprop-rs"
    fi
  else
    ui_print "- Skipping resetprop-rs, using built-in hexpatch"
  fi
fi

# Set Module permissions
set_perm_recursive "$MODPATH" 0 0 0755 0644
[ -f "$MODPATH/resetprop-rs" ] && chmod 755 "$MODPATH/resetprop-rs"

ui_print "? Please uninstall this module before dirty-flashing/updating the ROM."