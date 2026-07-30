#!/bin/bash

# =========================================================
#  PBI - Pterodactyl Blueprint Interactive GUI Installer
#  Repository: https://github.com/ProPlayer777bug/PBI
# =========================================================

# Set working directory to where command is run
WORKING_DIR="$(pwd)"
cd "$WORKING_DIR" || exit 1

# Check if Blueprint CLI is installed
if ! command -v blueprint &> /dev/null; then
    clear
    echo "❌ ERROR: 'blueprint' CLI command is not installed or not in PATH."
    echo "Please install the Blueprint framework first."
    exit 1
fi

# Search for .blueprint files in current directory
shopt -s nullglob
BLUEPRINTS=( *.blueprint )

if [ ${#BLUEPRINTS[@]} -eq 0 ]; then
    clear
    echo "=============================================="
    echo "❌ No .blueprint files found in:"
    echo "   $WORKING_DIR"
    echo "=============================================="
    echo "Please place your .blueprint files in this folder and run again."
    exit 1
fi

# Ensure whiptail GUI utility is available
if ! command -v whiptail &> /dev/null; then
    echo "⚙️ Installing 'whiptail' menu tool..."
    if command -v apt-get &> /dev/null; then
        apt-get update -y && apt-get install -y whiptail
    elif command -v yum &> /dev/null; then
        yum install -y newt
    fi
fi

# Build GUI Menu Options
MENU_ITEMS=("0" "⚡ INSTALL ALL BLUEPRINTS (${#BLUEPRINTS[@]} total)")

for i in "${!BLUEPRINTS[@]}"; do
    MENU_ITEMS+=("$((i + 1))" "${BLUEPRINTS[$i]}")
done

# Render Graphical Terminal Interface
CHOICE=$(whiptail --clear \
    --backtitle "Pterodactyl PBI Installer" \
    --title " Select Blueprint Package " \
    --menu "Use UP/DOWN arrow keys to navigate and press ENTER to select:" 18 70 10 \
    "${MENU_ITEMS[@]}" \
    3>&1 1>&2 2>&3)

# Handle Cancellation
if [ $? -ne 0 ]; then
    clear
    echo "Installation cancelled."
    exit 0
fi

clear

# Automated Installation Function
execute_installation() {
    local target_file="$1"
    local blueprint_identifier
    blueprint_identifier=$(basename "$target_file" .blueprint)

    echo "=============================================="
    echo " 🚀 Auto-Installing: $blueprint_identifier"
    echo "=============================================="

    # Pipe 'yes' to bypass interactive confirmation prompts inside Blueprint CLI
    if yes | blueprint -install "$blueprint_identifier"; then
        echo ""
        echo "✅ Successfully installed: $blueprint_identifier"
        rm -f "$target_file"
    else
        echo ""
        echo "❌ Failed to install: $blueprint_identifier"
        exit 1
    fi
    echo ""
}

# Run selection based on menu choice
if [ "$CHOICE" -eq 0 ]; then
    echo "Starting batch installation of all detected blueprints..."
    echo ""
    for file in "${BLUEPRINTS[@]}"; do
        execute_installation "$file"
    done
    echo "=============================================="
    echo "✅ All blueprint packages installed successfully!"
    echo "=============================================="
else
    SELECTED_INDEX=$((CHOICE - 1))
    TARGET_FILE="${BLUEPRINTS[$SELECTED_INDEX]}"
    execute_installation "$TARGET_FILE"
fi
