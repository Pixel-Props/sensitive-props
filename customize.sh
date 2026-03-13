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

  _vol_tmp="$TMPDIR/vol_key"
  _vol_sec=15
  : > "$_vol_tmp"
  getevent -qlc 1 > "$_vol_tmp" 2>/dev/null &
  _ge_pid=$!

  DO_DOWNLOAD=""
  while [ "$_vol_sec" -gt 0 ]; do
    sleep 1
    if ! kill -0 "$_ge_pid" 2>/dev/null; then
      _key=$(awk '/KEY_/{print $3}' "$_vol_tmp" 2>/dev/null)
      case "$_key" in
        KEY_VOLUMEUP)   DO_DOWNLOAD=true; break ;;
        KEY_VOLUMEDOWN) DO_DOWNLOAD=false; break ;;
      esac
      : > "$_vol_tmp"
      getevent -qlc 1 > "$_vol_tmp" 2>/dev/null &
      _ge_pid=$!
    fi
    _vol_sec=$((_vol_sec - 1))
  done

  kill "$_ge_pid" 2>/dev/null
  wait "$_ge_pid" 2>/dev/null
  rm -f "$_vol_tmp"

  # Timeout — fall back to config.prop
  if [ -z "$DO_DOWNLOAD" ]; then
    case "$_cfg_val" in
      false|0|off) DO_DOWNLOAD=false ;;
      *)           DO_DOWNLOAD=true ;;
    esac
  fi

  if [ "$DO_DOWNLOAD" = true ]; then
    ui_print "- Downloading resetprop-rs ($RESETPROP_RS_ASSET)..."
    _dl_ok=false
    if wget -qO "$MODPATH/resetprop-rs" "$RESETPROP_RS_URL/$RESETPROP_RS_ASSET" 2>/dev/null; then
      _dl_ok=true
    elif curl -sLo "$MODPATH/resetprop-rs" "$RESETPROP_RS_URL/$RESETPROP_RS_ASSET" 2>/dev/null; then
      _dl_ok=true
    fi

    if [ "$_dl_ok" = true ]; then
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

# Running the service early using busybox
[ -f "$MODPATH/service.sh" ] && busybox sh "$MODPATH/service.sh" 2>&1

ui_print "? Please uninstall this module before dirty-flashing/updating the ROM."