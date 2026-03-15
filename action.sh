#!/system/bin/busybox sh

MODPATH="${0%/*}"

# If MODPATH is empty or is not default modules path, use current path
[ -z "$MODPATH" ] || ! echo "$MODPATH" | grep -q '/data/adb/modules/' &&
  MODPATH="$(dirname "$(readlink -f "$0")")"

# Fallback for ui_print if not defined
type ui_print >/dev/null 2>&1 || ui_print() { echo "$@"; }

# Using util_functions.sh
[ -f "$MODPATH/util_functions.sh" ] && . "$MODPATH/util_functions.sh" || { ui_print "! util_functions.sh not found!"; exit 1; }

# ── Determine current status ──────────────────────────────────────
get_current_status() {
  if [ -f "$MODPATH/disable_cron" ]; then
    ui_print "Always Disabled"
  elif [ -f "$MODPATH/disable_cron_temp" ]; then
    ui_print "Disabled until Reboot"
  else
    _cfg=$(grep -s '^propscleaner_cron=' "$MODPATH/config.prop" | cut -d= -f2)
    if boolval "$_cfg"; then
      ui_print "Enabled"
    else
      ui_print "Always Disabled"
    fi
  fi
}

update_description() {
  # Backup before any edits
  [ -f "$PROP_FILE" ] && cp -f "$PROP_FILE" "$PROP_BAK"

  case "$1" in
    "Enabled")
      set_description "✅ Custom ROM spoofing enabled"
      ;;
    "Disabled until Reboot")
      set_description "⏸️ Custom ROM spoofing disabled until Reboot"
      ;;
    "Always Disabled")
      set_description "❌ Custom ROM spoofing disabled"
      ;;
  esac

  restore_prop_if_needed
}

# ── Main menu ─────────────────────────────────────────────────────
CURRENT=$(get_current_status)

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
  # ── Enable ────────────────────────────────────────────────────
  rm -f "$MODPATH/disable_cron" "$MODPATH/disable_cron_temp"

  # Persist to config.prop
  if grep -q '^propscleaner_cron=' "$MODPATH/config.prop" 2>/dev/null; then
    sed -i "s|^propscleaner_cron=.*|propscleaner_cron=true|" "$MODPATH/config.prop"
  else
    echo "propscleaner_cron=true" >> "$MODPATH/config.prop"
  fi

  # Start immediately
  sh "$MODPATH/propscleaner.sh" &
  [ ! -f "$MODPATH/crontabs/root" ] && {
    mkdir -p "$MODPATH/crontabs"
    echo "30 * * * * sh $MODPATH/propscleaner.sh > /dev/null 2>&1 &" | busybox crontab -c "$MODPATH/crontabs" -
  }
  [ -d "$MODPATH/crontabs" ] && busybox crond -bc "$MODPATH/crontabs" -L /dev/null > /dev/null 2>&1 &

  update_description "Enabled"

  ui_print "  ✅ Custom ROM spoofing ENABLED"
  ui_print ""

elif [ "$VOL_RESULT" = "down" ]; then
  # ── Disable sub-menu ──────────────────────────────────────────
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
    # ── Disable until Reboot ──────────────────────────────────
    rm -f "$MODPATH/disable_cron"
    touch "$MODPATH/disable_cron_temp"

    update_description "Disabled until Reboot"

    ui_print "  ⏸️  Custom ROM spoofing DISABLED until reboot"
    ui_print ""

  else
    # ── Always Disable (Vol- or timeout) ──────────────────────
    rm -f "$MODPATH/disable_cron_temp"
    touch "$MODPATH/disable_cron"

    # Persist to config.prop
    if grep -q '^propscleaner_cron=' "$MODPATH/config.prop" 2>/dev/null; then
      sed -i "s|^propscleaner_cron=.*|propscleaner_cron=false|" "$MODPATH/config.prop"
    else
      echo "propscleaner_cron=false" >> "$MODPATH/config.prop"
    fi

    update_description "Always Disabled"

    ui_print "  ❌ Custom ROM spoofing ALWAYS DISABLED"
    ui_print ""
  fi

else
  # ── Timeout — no change ───────────────────────────────────────
  ui_print "  No input received. No changes made."
  ui_print "  Current status remains: $CURRENT"
  ui_print ""
fi

ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print ""
