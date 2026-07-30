#!/bin/bash

# =========================================================
#  PBI - Fixed Terminal Blueprint Installer
#  Repository: ProPlayer777bug/PBI (Branch: blueprints)
# =========================================================

REPO_USER="ProPlayer777bug"
REPO_NAME="PBI"
BRANCH="blueprints"

# Ensure script operates inside Pterodactyl root directory
if [ -d "/var/www/pterodactyl" ]; then
    cd /var/www/pterodactyl || exit 1
else
    cd "$(pwd)" || exit 1
fi

clear

echo "=============================================="
echo "       Pterodactyl Blueprint Installer        "
echo "=============================================="
echo ""

# Check for Blueprint CLI
if ! command -v blueprint &> /dev/null; then
    echo "⚠️  WARNING: 'blueprint' CLI command is not installed on this system."
    echo "    Make sure you run this script inside /var/www/pterodactyl."
    echo ""
fi

# Ensure jq exists
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

# Fetch list of .blueprint files from GitHub API
API_URL="https://api.github.com/repos/$REPO_USER/$REPO_NAME/contents?ref=$BRANCH"
RESPONSE=$(curl -sSL "$API_URL")

# Parse filenames into array
mapfile -t BLUEPRINTS < <(echo "$RESPONSE" | jq -r '.[] | select(.name | endswith(".blueprint")) | .name')

if [ ${#BLUEPRINTS[@]} -eq 0 ] || [ "${BLUEPRINTS[0]}" == "null" ]; then
    echo "❌ No .blueprint files found in repository '$REPO_USER/$REPO_NAME' on branch '$BRANCH'!"
    exit 1
fi

# Output terminal list
echo "Select an option:"
echo "----------------------------------------------"
echo " [ 0] ⚡ INSTALL ALL BLUEPRINTS (${#BLUEPRINTS[@]} total)"
echo "----------------------------------------------"
for i in "${!BLUEPRINTS[@]}"; do
    printf " [%2d] %s\n" "$((i + 1))" "${BLUEPRINTS[$i]}"
done
echo "----------------------------------------------"
echo ""

# Read number selection directly from TTY
read -p "Enter selection (0-${#BLUEPRINTS[@]}): " CHOICE < /dev/tty

# Validate selection
if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 0 ] || [ "$CHOICE" -gt "${#BLUEPRINTS[@]}" ]; then
    echo ""
    echo "❌ Invalid selection. Exiting."
    exit 1
fi

download_and_install() {
    local file="$1"
    local raw_url="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/$BRANCH/$file"
    
    # Strip extension to pass clean identifier to blueprint (e.g., eggchanger)
    local identifier="${file%.blueprint}"

    echo "----------------------------------------------"
    echo "📥 Downloading: $file"
    echo "----------------------------------------------"

    # Download raw file
    curl -sSL -o "$file" "$raw_url"

    # Verify download success
    if [ ! -s "$file" ]; then
        echo "❌ Download failed! File is empty or 404 URL."
        rm -f "$file"
        return 1
    fi

    echo "🚀 Installing: $identifier"
    echo "----------------------------------------------"

    # Blueprint CLI expects $file (eggchanger.blueprint) present in directory 
    # while passing $identifier (eggchanger) to the install argument
    if yes | blueprint -install "$identifier"; then
        echo "✅ Successfully installed: $identifier"
        rm -f "$file"
    else
        echo "❌ Installation failed for: $identifier"
        rm -f "$file"
        return 1
    fi
    echo ""
}

# Process Option
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
