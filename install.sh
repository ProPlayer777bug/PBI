#!/bin/bash

# =========================================================
#  PBI - Pure Terminal Text Installer (Zero Whiptail/GUI)
#  Repository: ProPlayer777bug/PBI
# =========================================================

REPO_USER="ProPlayer777bug"
REPO_NAME="PBI"
BRANCH="blueprints"

cd "$(pwd)" || exit 1
clear

echo "=============================================="
echo "       Pterodactyl Blueprint Installer        "
echo "=============================================="
echo ""

# Check for Blueprint CLI
if ! command -v blueprint &> /dev/null; then
    echo "⚠️  WARNING: 'blueprint' CLI command is not installed on this system."
    echo "    Make sure you run this script on your Pterodactyl server."
    echo ""
fi

# Ensure jq exists to parse GitHub API JSON
if ! command -v jq &> /dev/null; then
    echo "⚙️  Installing required dependency (jq)..."
    if command -v apt-get &> /dev/null; then
        apt-get update -y >/dev/null 2>&1
        apt-get install -y jq curl >/dev/null 2>&1
    elif command -v yum &> /dev/null; then
        yum install -y jq curl >/dev/null 2>&1
    fi
fi

echo "🔍 Fetching available blueprints from GitHub..."
echo ""

# Fetch list of .blueprint files directly from GitHub API
API_URL="https://api.github.com/repos/$REPO_USER/$REPO_NAME/contents?ref=$BRANCH"
RESPONSE=$(curl -sSL "$API_URL")

# Parse filenames into array
mapfile -t BLUEPRINTS < <(echo "$RESPONSE" | jq -r '.[] | select(.name | endswith(".blueprint")) | .name')

if [ ${#BLUEPRINTS[@]} -eq 0 ] || [ "${BLUEPRINTS[0]}" == "null" ]; then
    echo "❌ No .blueprint files found in repository '$REPO_USER/$REPO_NAME' on branch '$BRANCH'!"
    exit 1
fi

# Output plain terminal list
echo "Select an option:"
echo "----------------------------------------------"
echo " [ 0] ⚡ INSTALL ALL BLUEPRINTS (${#BLUEPRINTS[@]} total)"
echo "----------------------------------------------"
for i in "${!BLUEPRINTS[@]}"; do
    printf " [%2d] %s\n" "$((i + 1))" "${BLUEPRINTS[$i]}"
done
echo "----------------------------------------------"
echo ""

# Read number selection straight from the TTY (crucial for curl piped execution)
read -p "Enter selection (0-${#BLUEPRINTS[@]}): " CHOICE < /dev/tty

# Validate input
if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 0 ] || [ "$CHOICE" -gt "${#BLUEPRINTS[@]}" ]; then
    echo ""
    echo "❌ Invalid selection. Exiting."
    exit 1
fi

download_and_install() {
    local file="$1"
    local raw_url="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/$BRANCH/$file"
    local name="${file%.blueprint}"

    echo "----------------------------------------------"
    echo "📥 Downloading: $file"
    echo "----------------------------------------------"

    curl -sSL -o "$file" "$raw_url"

    if [ ! -s "$file" ]; then
        echo "❌ Download failed or file is empty for $file"
        rm -f "$file"
        return 1
    fi

    echo "🚀 Installing: $name"
    echo "----------------------------------------------"

    if yes | blueprint -install "$name"; then
        echo "✅ Successfully installed: $name"
        rm -f "$file"
    else
        echo "❌ Installation failed for: $name"
        rm -f "$file"
        return 1
    fi
    echo ""
}

# Execute installation logic
if [ "$CHOICE" -eq 0 ]; then
    echo ""
    echo "=============================================="
    echo " 🚀 Starting batch installation of ALL blueprints..."
    echo "=============================================="
    echo ""
    for file in "${BLUEPRINTS[@]}"; do
        download_and_install "$file"
    done
    echo "=============================================="
    echo "✅ All blueprint installation tasks completed!"
    echo "=============================================="
else
    SELECTED_FILE="${BLUEPRINTS[$((CHOICE - 1))]}"
    
    echo ""
    echo "=============================================="
    echo " 🚀 Installing target: ${SELECTED_FILE%.blueprint}"
    echo "=============================================="
    echo ""

    download_and_install "$SELECTED_FILE"
fi
