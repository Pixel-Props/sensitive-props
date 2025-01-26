#!/system/bin/busybox sh

# Function that normalizes a boolean value and returns 0, 1, or a string
# Usage: boolval "value"
boolval() {
    case "$(printf "%s" "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    1 | true | on | enabled) return 0 ;;    # Truely
    0 | false | off | disabled) return 1 ;; # Falsely
    *) return 1 ;;                          # Everything else - return a string
    esac
}

# Enhanced boolval function to only identify booleans
is_bool() {
    case "$(printf "%s" "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    1 | true | on | enabled | 0 | false | off | disabled) return 0 ;; # True (is a boolean)
    *) return 1 ;;                                                    # False (not a boolean)
    esac
}

# Function to print a message to the user interface.
ui_print() { echo "$1"; }

# Function to abort the script with an error message.
abort() {
    message="$1"
    remove_module="${2:-true}"

    ui_print " [!] $message"

    # Remove module on next reboot if requested
    if boolval "$remove_module"; then
        touch "$MODPATH/remove"
        ui_print " ! The module will be removed on next reboot !"
        ui_print ""
        sleep 5
        exit 1
    fi

    sleep 5
    return 1
}

set_permissions() { # Handle permissions without errors
    [ -e "$1" ] && chmod "$2" "$1" &>/dev/null
}

# Function to construct arguments for resetprop based on prop name
_build_resetprop_args() {
    prop_name="$1"
    shift

    case "$prop_name" in
    persist.*) set -- -p -v "$prop_name" ;; # Use persist mode
    *) set -- -n -v "$prop_name" ;;         # Use normal mode
    esac
    echo "$@"
}

exist_resetprop() { # Reset a property if it exists
    getprop "$1" | grep -q '.' && resetprop $(_build_resetprop_args "$1") ""
}

check_resetprop() { # Reset a property if it exists and doesn't match the desired value
    VALUE="$(resetprop -v "$1")"
    [ ! -z "$VALUE" ] && [ "$VALUE" != "$2" ] && resetprop $(_build_resetprop_args "$1") "$2"
}

maybe_resetprop() { # Reset a property if it exists and matches a pattern
    VALUE="$(resetprop -v "$1")"
    [ ! -z "$VALUE" ] && echo "$VALUE" | grep -q "$2" && resetprop $(_build_resetprop_args "$1") "$3"
}

replace_value_resetprop() { # Replace a substring in a property's value
    VALUE="$(resetprop -v "$1")"
    [ -z "$VALUE" ] && return
    VALUE_NEW="$(echo -n "$VALUE" | sed "s|${2}|${3}|g")"
    [ "$VALUE" == "$VALUE_NEW" ] || resetprop $(_build_resetprop_args "$1") "$VALUE_NEW"
}

# This function aims to delete or obfuscate specific strings within Android system properties,
# by replacing them with random hexadecimal values which should match with the original string length.
hexpatch_deleteprop() {
    # Path to magiskboot (determine it once, at the beginning)
    magiskboot_path=$(which magiskboot 2>/dev/null || find /data/adb /data/data/me.bmax.apatch/patch/ -name magiskboot -print -quit 2>/dev/null)
    [ -z "$magiskboot_path" ] && abort "magiskboot not found" false

    # Loop through all arguments passed to the function
    for search_string in "$@"; do
        # Hex representation in uppercase
        search_hex=$(echo -n "$search_string" | xxd -p | tr '[:lower:]' '[:upper:]')

        # Generate a random LOWERCASE alphanumeric string of the required length, using only 0-9 and a-f
        replacement_string=$(cat /dev/urandom | tr -dc '0-9a-f' | head -c ${#search_string})

        # Convert the replacement string to hex and ensure it's in uppercase
        replacement_hex=$(echo -n "$replacement_string" | xxd -p | tr '[:lower:]' '[:upper:]')

        # Get property list from search string
        # Then get a list of property file names using resetprop -Z and pipe it to find
        getprop | cut -d'[' -f2 | cut -d']' -f1 | grep "$search_string" | while read prop_name; do
            resetprop -Z "$prop_name" | cut -d' ' -f2 | cut -d':' -f3 | while read -r prop_file_name_base; do
                # Use find to locate the actual property file (potentially in a subdirectory)
                # and iterate directly over the found paths
                find /dev/__properties__/ -name "*$prop_file_name_base*" | while read -r prop_file; do
                    # echo "Patching $prop_file: $search_hex -> $replacement_hex"
                    "$magiskboot_path" hexpatch "$prop_file" "$search_hex" "$replacement_hex" >/dev/null 2>&1

                    # Check if the patch was successfully applied
                    if [ $? -eq 0 ]; then
                        echo " ? Successfully patched $prop_file (replaced part of '$search_string' with '$replacement_string')"
                    # else
                    #   echo " ! Failed to patch $prop_file (replacing part of '$search_string')."
                    fi
                done
            done

            # Unset the property after patching to ensure the change takes effect
            resetprop -n --delete "$prop_name"
            ret=$?

            if [ $ret -eq 0 ]; then
                echo " ? Successfully unset $prop_name"
            else
                echo " ! Failed to unset $prop_name"
            fi
        done
    done
}

# Since it is unsafe to change full length strings within binary image pages
# We must specify short strings for the search so that there are not binary chunks in between
# magiskboot hexpatch issue
# ref: https://github.com/topjohnwu/Magisk/issues/8315
# tldr; use hexpatch_deleteprop instead.
hexpatch_replaceprop() {
    search_string="$1" # The string to search for in property names
    new_string="$2"    # The new string to replace the search string with

    # Check if lengths match, abort if not
    if [ ${#search_string} -ne ${#new_string} ]; then
        abort "Error: Searching/Replacing string using hexpatch must have the new string to be of the same length." false >&2
    fi

    search_hex=$(echo -n "$search_string" | xxd -p | tr '[:lower:]' '[:upper:]') # Hex representation in uppercase
    replace_hex=$(echo -n "$new_string" | xxd -p | tr '[:lower:]' '[:upper:]')   # Hex representation of the new string, also uppercase

    # Path to magiskboot
    magiskboot_path=$(which magiskboot 2>/dev/null || find /data/adb /data/data/me.bmax.apatch/patch/ -name magiskboot -print -quit 2>/dev/null)

    # Get property list from search string
    # Then get a list of property file names using resetprop -Z and pipe it to find
    getprop | cut -d'[' -f2 | cut -d']' -f1 | grep "$search_string" | while read prop_name; do
        resetprop -Z "$prop_name" | cut -d' ' -f2 | cut -d':' -f3 | while read -r prop_file_name_base; do
            # Use find to locate the actual property file (potentially in a subdirectory)
            # and iterate directly over the found paths
            find /dev/__properties__/ -name "*$prop_file_name_base*" | while read -r prop_file; do
                # echo "Patching $prop_file: $search_hex -> $replace_hex"
                "$magiskboot_path" hexpatch "$prop_file" "$search_hex" "$replace_hex" >/dev/null 2>&1

                # Check if the patch was successfully applied
                if [ $? -eq 0 ]; then
                    echo " ? Successfully patched $prop_file (renamed part of '$search_string' to '$new_string')"
                    #else
                    #echo " ! Failed to patch $prop_file (renaming part of '$search_string')."
                fi
            done
        done
    done
}
