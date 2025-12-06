#!/usr/bin/env bash

# scifox Installer (Robust Version)
# Locates profiles by scanning for 'prefs.js' directly.
# Handles spaces in filenames and POSIX compliance.

set -u

# --- Configuration ---
CHROME_SRC="chrome"
USERJS_SRC="user.js"

# --- Colors ---
c_red='\033[0;31m'
c_green='\033[0;32m'
c_blue='\033[0;34m'
c_reset='\033[0m'

# --- Headers ---
echo_info() { printf "%b→ %s%b\n" "$c_blue" "$1" "$c_reset"; }
echo_success() { printf "%b✓ %s%b\n" "$c_green" "$1" "$c_reset"; }
echo_err() { printf "%b✗ %s%b\n" "$c_red" "$1" "$c_reset"; }

# --- Logic ---

# 1. Detect Firefox Root Directory
get_firefox_root() {
    if [ -d "$HOME/.mozilla/firefox" ]; then
        echo "$HOME/.mozilla/firefox"
    elif [ -d "$HOME/Library/Application Support/Firefox/Profiles" ]; then
        echo "$HOME/Library/Application Support/Firefox/Profiles"
    elif [ -d "$HOME/Library/Application Support/Firefox" ]; then
        echo "$HOME/Library/Application Support/Firefox"
    else
        return 1
    fi
}

# 2. Main Execution
main() {
    # Clear screen for a clean start
    printf "\n%b❄️  scifox Installer%b\n" "$c_blue" "$c_reset"
    printf "%b==================%b\n\n" "$c_blue" "$c_reset"

    # Check source files
    if [ ! -d "$CHROME_SRC" ] || [ ! -f "$USERJS_SRC" ]; then
        echo_err "Files missing!"
        echo "   Ensure '$CHROME_SRC' folder and '$USERJS_SRC' are in this directory."
        exit 1
    fi

    # Find Root
    FF_ROOT=$(get_firefox_root) || {
        echo_err "Could not find Firefox directory."
        exit 1
    }
    echo_success "Found Firefox Root: $FF_ROOT"

    # Find Profiles (Scanning for prefs.js)
    TMP_LIST="/tmp/scifox_targets.$$"
    : > "$TMP_LIST"

    count=0
    
    # Iterate over any directory containing prefs.js
    for prefs_path in "$FF_ROOT"/*/prefs.js; do
        [ -e "$prefs_path" ] || continue
        
        profile_dir="${prefs_path%/*}"
        dir_name="${profile_dir##*/}"
        
        count=$((count + 1))
        
        echo "$profile_dir" >> "$TMP_LIST"
        
        # Try to find a pretty name from profiles.ini (cosmetic only)
        pretty_name=""
        if [ -f "$FF_ROOT/profiles.ini" ]; then
            pretty_name=$(grep -C 5 "$dir_name" "$FF_ROOT/profiles.ini" | grep "^Name=" | head -n 1 | cut -d= -f2 | tr -d '\r')
        fi
        
        if [ -n "$pretty_name" ]; then
            printf "  %b%d)%b %s %b(%s)%b\n" "$c_green" "$count" "$c_reset" "$pretty_name" "$c_blue" "$dir_name" "$c_reset"
        else
            printf "  %b%d)%b %s\n" "$c_green" "$count" "$c_reset" "$dir_name"
        fi
    done

    if [ "$count" -eq 0 ]; then
        echo_err "No profiles found (looked for */prefs.js)."
        exit 1
    fi

    # Interactive Selection
    echo ""
    printf "Options: [%bA%b]ll, [%bS%b]elect numbers, [%bQ%b]uit: " "$c_green" "$c_reset" "$c_green" "$c_reset" "$c_red" "$c_reset"
    read -r choice

    case "$choice" in
        q|Q) echo_info "Aborted."; rm "$TMP_LIST"; exit 0 ;;
        a|A) indices=$(seq 1 "$count") ;;
        s|S)
            printf "Enter numbers (e.g. 1 2): "
            read -r selection_input
            indices="$selection_input"
            ;;
        *) echo_err "Invalid choice."; rm "$TMP_LIST"; exit 1 ;;
    esac

    echo ""

    # Installation Loop
    for i in $indices; do
        # Validate number
        if echo "$i" | grep -qvE '^[0-9]+$' || [ "$i" -lt 1 ] || [ "$i" -gt "$count" ]; then
            echo_err "Skipping invalid number: $i"
            continue
        fi

        # Extract line N from temp file
        target_path=$(sed -n "${i}p" "$TMP_LIST")
        target_name="${target_path##*/}"

        echo_info "Installing to: $target_name"

        # 1. Handle Chrome Folder
        if [ -d "$target_path/$CHROME_SRC" ]; then
            rm -rf "$target_path/${CHROME_SRC}.bak"
            mv "$target_path/$CHROME_SRC" "$target_path/${CHROME_SRC}.bak"
            echo_info "Backed up existing chrome folder to ${CHROME_SRC}.bak"
        fi
        cp -r "$CHROME_SRC" "$target_path/"
        
        # 2. Handle User.js
        if [ -f "$target_path/$USERJS_SRC" ]; then
            # Backup existing user.js
            mv "$target_path/$USERJS_SRC" "$target_path/${USERJS_SRC}.bak"
            echo_info "Backed up existing user.js to ${USERJS_SRC}.bak"
        fi
        cp "$USERJS_SRC" "$target_path/"

        echo_success "Done."
    done

    # Cleanup
    rm "$TMP_LIST"

    echo ""
    echo_success "Installation Complete."
    echo "  0. Install the FantasqueSansM Nerd Font."
    echo "  1. Restart Firefox."
    echo "  2. Customize Toolbar and Clear the UI."
    echo "  3. Install Adaptive Tab Bar Color addon."
    echo "  4. Install Sidebery addon."
    echo "  5. Import sidebery.json in Sidebery settings."
}

main
