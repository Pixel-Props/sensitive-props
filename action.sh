#!/system/bin/busybox sh

MODPATH="${0%/*}"

# If MODPATH is empty or is not default modules path, use current path
[ -z "$MODPATH" ] || ! echo "$MODPATH" | grep -q '/data/adb/modules/' &&
  MODPATH="$(dirname "$(readlink -f "$0")")"

# Fallback for ui_print if not defined
type ui_print >/dev/null 2>&1 || ui_print() { echo "$@"; }

# Using util_functions.sh
[ -f "$MODPATH/util_functions.sh" ] && . "$MODPATH/util_functions.sh" || { ui_print "! util_functions.sh not found!"; exit 1; }

# Determine current cron status
get_cron_status() {
  if [ -f "$MODPATH/disable_cron" ]; then
    echo "Always Disabled"
  elif [ -f "$MODPATH/disable_cron_temp" ]; then
    echo "Disabled until Reboot"
  else
    # config.prop fallback
    _cron_cfg=$(grep -s '^propscleaner_cron=' "$MODPATH/config.prop" | cut -d= -f2)
    if boolval "$_cron_cfg"; then
      echo "Enabled"
    else
      echo "Always Disabled"
    fi
  fi
}

update_description() {
  _cron_status=$(get_cron_status)
  case "$_cron_status" in
    "Enabled")              _cron_tag="[✅ Custom ROM spoofing," ;;
    "Disabled until Reboot") _cron_tag="[⏸️ Custom ROM spoofing," ;;
    *)                      _cron_tag="[❌ Custom ROM spoofing," ;;
  esac

  _rs_cfg=$(grep -s '^download_resetprop_rs=' "$MODPATH/config.prop" | cut -d= -f2)
  if boolval "$_rs_cfg"; then
    _rs_tag="✅ resetprop-rs]"
  else
    _rs_tag="❌ resetprop-rs]"
  fi

  set_description "$_cron_tag $_rs_tag"
  restore_desc_if_needed
}

# Detect device architecture for resetprop-rs
RESETPROP_RS_URL="https://github.com/Enginex0/resetprop-rs/releases/latest/download"
_arch=$(uname -m 2>/dev/null)
case "$_arch" in
  aarch64*) RESETPROP_RS_ASSET="resetprop-arm64-v8a" ;;
  armv7*|armv8l) RESETPROP_RS_ASSET="resetprop-armeabi-v7a" ;;
  *)        RESETPROP_RS_ASSET="" ;;
esac

# Crontabs config
CURRENT=$(get_cron_status)

ui_print ""
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print "  Custom ROM Spoofing Configuration"
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print ""
ui_print "  Current status: $CURRENT"
ui_print ""
ui_print "  [Vol+] Enable"
ui_print "  [Vol-] Disable options"
ui_print ""
ui_print "  Waiting for input (15s timeout)..."
ui_print ""

vol_key_wait 15

if [ "$VOL_RESULT" = "up" ]; then
  # Enable
  rm -f "$MODPATH/disable_cron" "$MODPATH/disable_cron_temp"

  # Override config.prop
  sed -i "s|^propscleaner_cron=.*|propscleaner_cron=true|" "$MODPATH/config.prop"

  # Start immediately
  sh "$MODPATH/propscleaner.sh" &
  [ ! -f "$MODPATH/crontabs/root" ] && {
    mkdir -p "$MODPATH/crontabs"
    echo "30 * * * * sh $MODPATH/propscleaner.sh > /dev/null 2>&1 &" | busybox crontab -c "$MODPATH/crontabs" -
  }
  [ -d "$MODPATH/crontabs" ] && busybox crond -bc "$MODPATH/crontabs" -L /dev/null > /dev/null 2>&1 &

  ui_print "  ✅ Custom ROM spoofing ENABLED"
  ui_print ""

elif [ "$VOL_RESULT" = "down" ]; then
  # Show disable sub-menu
  ui_print ""
  ui_print "  Choose disable mode:"
  ui_print ""
  ui_print "  [Vol+] Disable until Reboot"
  ui_print "  [Vol-] Always Disable"
  ui_print ""
  ui_print "  Waiting for input (15s timeout)..."
  ui_print ""

  vol_key_wait 15

    # Stop crond and remove crontab
    busybox pkill -f "crond -bc $MODPATH/crontabs" 2>/dev/null
    rm -rf "$MODPATH/crontabs"

  if [ "$VOL_RESULT" = "up" ]; then
    # Disable until Reboot
    if [ "$CURRENT" == "Always Disabled" ]; then
      rm -f "$MODPATH/disable_cron"
    fi
    touch "$MODPATH/disable_cron_temp"

    # Override config.prop
    sed -i "s|^propscleaner_cron=.*|propscleaner_cron=true|" "$MODPATH/config.prop"

    ui_print "  ⏸️ Custom ROM spoofing DISABLED until Reboot"
    ui_print ""

  elif [ "$VOL_RESULT" = "down" ]; then
    # Always Disable
    if [ "$CURRENT" == "Disabled until Reboot" ]; then
      rm -f "$MODPATH/disable_cron_temp"
    fi
    touch "$MODPATH/disable_cron"

    # Override config.prop
    sed -i "s|^propscleaner_cron=.*|propscleaner_cron=false|" "$MODPATH/config.prop"

    ui_print "  ❌ Custom ROM spoofing ALWAYS DISABLED"
    ui_print ""

  else
    # Timeout
    ui_print "  No input received. No changes made."
    ui_print "  Current status remains: $CURRENT"
    ui_print ""
  fi

else
  # Timeout
  ui_print "  No input received. No changes made."
  ui_print "  Current status remains: $CURRENT"
  ui_print ""
fi

ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print ""

# resetprop-rs config
if [ -n "$RESETPROP_RS_ASSET" ]; then
  if boolval "$_rs_cfg"; then
    _rs_status="Installed"
  else
    _rs_status="Not installed"
  fi

  ui_print ""
  ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  ui_print "  resetprop-rs Configuration"
  ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  ui_print ""
  ui_print "  Current status: $_rs_status"
  ui_print ""
  if [ "$_rs_status" = "Installed" ]; then
    ui_print "  [Vol+] Keep installed"
    ui_print "  [Vol-] Remove"
  else
    ui_print "  [Vol+] Download & Install"
    ui_print "  [Vol-] Skip"
  fi
  ui_print ""
  ui_print "  Waiting for input (15s timeout)..."
  ui_print ""

  vol_key_wait 15

  if [ "$_rs_status" = "Installed" ]; then
    # Currently installed
    if [ "$VOL_RESULT" = "down" ]; then
      rm -f "$MODPATH/resetprop-rs"

      # Override config.prop
      sed -i "s|^download_resetprop_rs=.*|download_resetprop_rs=false|" "$MODPATH/config.prop"

      ui_print "  🗑️ resetprop-rs REMOVED"
      ui_print ""

    elif [ "$VOL_RESULT" = "up" ]; then
      ui_print "  resetprop-rs kept."
      ui_print ""

    else
      # Timeout
      ui_print "  No input received. No changes made."
      ui_print "  Current status remains: $_rs_status"
      ui_print ""
    fi

  else
    # Not installed
    if [ "$VOL_RESULT" = "up" ]; then
      ui_print "  Downloading resetprop-rs ($RESETPROP_RS_ASSET)..."
      if wget -qO "$MODPATH/resetprop-rs" "$RESETPROP_RS_URL/$RESETPROP_RS_ASSET" 2>/dev/null || \
         curl -sLo "$MODPATH/resetprop-rs" "$RESETPROP_RS_URL/$RESETPROP_RS_ASSET" 2>/dev/null; then
        _dl_ok=true
      else
        _dl_ok=false
      fi

      if boolval "$_dl_ok"; then
        chmod 755 "$MODPATH/resetprop-rs"
        if "$MODPATH/resetprop-rs" -h >/dev/null 2>&1; then
          ui_print "  ✅ resetprop-rs installed successfully"
          ui_print ""
        else
          rm -f "$MODPATH/resetprop-rs"
          ui_print "  ! resetprop-rs binary failed smoke test, removing"
          ui_print ""
          _dl_ok=false
        fi
      else
        rm -f "$MODPATH/resetprop-rs"
        ui_print "  ! Download failed"
        ui_print ""
      fi

    elif [ "$VOL_RESULT" = "down" ]; then
      ui_print "  Skipped resetprop-rs."
      ui_print ""
      _dl_ok=false

    else
      # Timeout
      ui_print "  No input received. No changes made."
      ui_print "  Current status remains: $_rs_status"
      ui_print ""
    fi

    # Override config.prop
    sed -i "s|^download_resetprop_rs=.*|download_resetprop_rs=$_dl_ok|" "$MODPATH/config.prop"
  fi

  ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  ui_print ""
fi

update_description
