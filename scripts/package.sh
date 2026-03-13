#!/usr/bin/env bash
# Build, package, deploy, and verify sensitive-props module.
# Usage: ./scripts/package.sh [flags]
#
# Examples:
#   ./scripts/package.sh                               # package ZIP
#   ./scripts/package.sh --deploy --reboot              # package, push, install, reboot
#   ./scripts/package.sh --deploy --verify              # deploy + verify props via adb
#   ./scripts/package.sh --verify                       # verify-only (no build/deploy)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$PROJECT_ROOT/out"

DEPLOY=false
REBOOT=false
VERIFY=false
CLEAN=false
TRACE=false
ROOT_PROVIDER="ksu"

red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Package options:
  --clean            Remove previous builds before packaging

Deploy options:
  --deploy           Push ZIP to device and install
  --reboot           Reboot device after install
  --verify           Check module state and spoofed properties
  --root PROVIDER    Root provider: ksu (default), magisk, apatch

Misc:
  -v, --verbose      Print every command as it runs (set -x)
  --help             Show this help
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean)      CLEAN=true; shift ;;
        --deploy)     DEPLOY=true; shift ;;
        --reboot)     REBOOT=true; shift ;;
        --verify)     VERIFY=true; shift ;;
        -v|--verbose) TRACE=true; shift ;;
        --root)       ROOT_PROVIDER="$2"; shift 2 ;;
        --help|-h)    usage ;;
        *)            red "Unknown flag: $1"; usage ;;
    esac
done

[[ "$TRACE" == true ]] && set -x

case "$ROOT_PROVIDER" in
    ksu)     INSTALL_CMD="ksud module install" ;;
    magisk)  INSTALL_CMD="magisk --install-module" ;;
    apatch)  INSTALL_CMD="/data/adb/apd module install" ;;
    *)       red "Unknown root provider: $ROOT_PROVIDER"; exit 1 ;;
esac

MODULE_ID=$(grep '^id=' "$PROJECT_ROOT/module.prop" | cut -d= -f2)
MODULE_VER=$(grep '^version=' "$PROJECT_ROOT/module.prop" | cut -d= -f2)

MODULE_FILES=(
    META-INF
    customize.sh
    service.sh
    post-fs-data.sh
    util_functions.sh
    module.prop
    oem.rc
    sepolicy.rule
    uninstall.sh
    config.prop
)

package_zip() {
    [[ "$CLEAN" == true ]] && rm -rf "$OUT_DIR"
    mkdir -p "$OUT_DIR"

    local zip_name="${MODULE_ID}-${MODULE_VER}.zip"
    local zip_path="$OUT_DIR/$zip_name"

    rm -f "$zip_path"

    bold "==> Packaging $zip_name"

    local missing=false
    for f in "${MODULE_FILES[@]}"; do
        if [[ ! -e "$PROJECT_ROOT/$f" ]]; then
            red "    Missing: $f"
            missing=true
        fi
    done
    [[ "$missing" == true ]] && exit 1

    (cd "$PROJECT_ROOT" && zip -r9 "$zip_path" "${MODULE_FILES[@]}" -x '*.DS_Store' '*.swp')

    local size
    size=$(du -h "$zip_path" | cut -f1)
    green "    $zip_name ($size)"
}

deploy_zip() {
    local zip
    zip=$(ls -t "$OUT_DIR"/${MODULE_ID}-*.zip 2>/dev/null | head -1)

    if [[ -z "$zip" ]]; then
        red "No ZIP found in $OUT_DIR"
        exit 1
    fi

    if ! adb get-state &>/dev/null; then
        red "No ADB device connected"
        exit 1
    fi

    local name
    name=$(basename "$zip")
    bold "==> Deploying $name"
    adb push "$zip" /data/local/tmp/module.zip
    adb shell "su -c '$INSTALL_CMD /data/local/tmp/module.zip'"
    green "    Installed via $ROOT_PROVIDER"

    if [[ "$REBOOT" == true ]]; then
        bold "==> Rebooting"
        adb reboot
        echo "    Waiting for device..."
        adb wait-for-device
        sleep 15
    fi
}

verify_device() {
    bold "==> Verification"

    if ! adb get-state &>/dev/null; then
        red "No ADB device connected"
        exit 1
    fi

    # Module presence
    local mod_active
    mod_active=$(adb shell "su -c '[ -d /data/adb/modules/${MODULE_ID} ] && echo yes || echo no'")
    if [[ "$mod_active" == *"yes"* ]]; then
        green "    Module: installed"
    else
        red "    Module: not found"
        return
    fi

    local disabled
    disabled=$(adb shell "su -c '[ -f /data/adb/modules/${MODULE_ID}/disable ] && echo yes || echo no'")
    [[ "$disabled" == *"yes"* ]] && yellow "    Module: DISABLED"

    local rp_rs
    rp_rs=$(adb shell "su -c '[ -x /data/adb/modules/${MODULE_ID}/resetprop-rs ] && echo yes || echo no'")
    if [[ "$rp_rs" == *"yes"* ]]; then
        green "    resetprop-rs: present"
    else
        yellow "    resetprop-rs: not present (using magiskboot fallback)"
    fi

    # Key property checks
    echo "    --- Property Checks ---"
    local checks=(
        "ro.boot.verifiedbootstate:green"
        "ro.boot.vbmeta.device_state:locked"
        "ro.debuggable:0"
        "ro.secure:1"
        "ro.adb.secure:1"
        "sys.oem_unlock_allowed:0"
    )

    local pass=0 fail=0
    for check in "${checks[@]}"; do
        local prop="${check%%:*}"
        local expected="${check##*:}"
        local actual
        actual=$(adb shell "getprop $prop" 2>/dev/null | tr -d '\r\n')

        if [[ "$actual" == "$expected" ]]; then
            green "    $prop = $actual"
            pass=$((pass + 1))
        elif [[ -z "$actual" ]]; then
            echo "    $prop = (empty/unset)"
            pass=$((pass + 1))
        else
            red "    $prop = $actual (expected: $expected)"
            fail=$((fail + 1))
        fi
    done

    # Build tags/type across partitions
    local tag_issues=0
    for prefix in system vendor product; do
        local tags
        tags=$(adb shell "getprop ro.${prefix}.build.tags" 2>/dev/null | tr -d '\r\n')
        [[ -n "$tags" ]] && [[ "$tags" != "release-keys" ]] && {
            red "    ro.${prefix}.build.tags = $tags"
            tag_issues=$((tag_issues + 1))
        }
        local btype
        btype=$(adb shell "getprop ro.${prefix}.build.type" 2>/dev/null | tr -d '\r\n')
        [[ -n "$btype" ]] && [[ "$btype" != "user" ]] && {
            red "    ro.${prefix}.build.type = $btype"
            tag_issues=$((tag_issues + 1))
        }
    done
    [[ "$tag_issues" -eq 0 ]] && green "    Build tags/type: all clean"

    # Custom ROM trace scan
    local traces
    traces=$(adb shell "getprop" 2>/dev/null | grep -icE 'lineage|crdroid|evolution|grapheneos|paranoid|calyxos' || true)
    if [[ "$traces" -eq 0 ]]; then
        green "    ROM traces: none detected"
    else
        yellow "    ROM traces: $traces properties still visible"
    fi

    echo ""
    echo "    Results: $pass passed, $fail failed"
}

# --- Main ---
echo ""
bold "sensitive-props package pipeline"
echo ""

if [[ "$VERIFY" == true ]] && [[ "$DEPLOY" == false ]]; then
    verify_device
else
    package_zip

    [[ "$DEPLOY" == true ]] && deploy_zip
    [[ "$VERIFY" == true ]] && verify_device
fi

echo ""
green "Done."
