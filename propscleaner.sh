#!/system/bin/busybox sh 
 
MODPATH="${0%/*}"

# Using util_functions.sh
[ -f "$MODPATH/util_functions.sh" ] && . "$MODPATH/util_functions.sh" || abort "! util_functions.sh not found!"
  
# Periodically hexpatch delete custom ROM props
hexpatch_deleteprop "LSPosed" \
  "marketname" "custom.device" "modversion" "kernel.qemu" \
  "lineage" "aospa" "pixelexperience" "evolution" "pixelos" "pixelage" "crdroid" "crDroid" \
  "aicp" "arter97" "blu_spark" "cyanogenmod" "deathly" "elementalx" "elite" "franco" "hadeskernel" \
  "morokernel" "noble" "optimus" "slimroms" "sultan" "aokp" "bharos" "calyxos" "calyxOS" "divestos" \
  "emteria.os" "grapheneos" "indus" "iodéos" "kali" "nethunter" "omnirom" "paranoid" "replicant" \
  "resurrection" "rising" "remix" "shift" "volla" "icosa" "kirisakura" "infinity" "Infinity"
