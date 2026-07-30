#!/bin/bash

# =========================================================
#  PBI - Fixed Terminal Blueprint Installer
#  Repository: ProPlayer777bug/PBI (Branch: blueprints)
# =========================================================

REPO_USER="ProPlayer777bug"
REPO_NAME="PBI"
BRANCH="blueprints"

# Force working directory to Pterodactyl root
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

# Verify Blueprint installation
if ! command -v blueprint &> /dev/null; then
    echo "⚠️  WARNING: 'blueprint' CLI command is not installed on this system."
    echo "    Please run this script inside /var/www/pterodactyl."
    echo ""
fi

# Ensure dependencies exist
if ! command -v jq &> /dev/null || ! command -v unzip &> /dev/null; then
    echo "⚙️  Installing required dependencies (jq, unzip)..."
    if command -v apt-get &> /dev/null; then
        apt-get update -y >/dev/null 2>&1
        apt-get install -y jq unzip curl >/dev/null 2>&1
    elif command -v yum &> /dev/null; then
        yum install -y jq unzip curl >/dev/null 2>&1
    fi
fi

echo "🔍 Fetching available blueprints from GitHub..."
echo ""

# Fetch list of .blueprint files
API_URL="https://api.github.com/repos/$REPO_USER/$REPO_NAME/contents?ref=$BRANCH"
RESPONSE=$(curl -sSL -H "User-Agent: Mozilla/5.0" "$API_URL")

# Store filenames in array
mapfile -t BLUEPRINTS < <(echo "$RESPONSE" | jq -r '.[] | select(.name | endswith(".blueprint")) | .name')

if [ ${#BLUEPRINTS[@]} -eq 0 ] || [ "${BLUEPRINTS[0]}" == "null" ]; then
    echo "❌ No .blueprint files found in '$REPO_USER/$REPO_NAME' ($BRANCH branch)!"
    exit 1
fi

echo "Select an option:"
echo "----------------------------------------------"
echo " [ 0] ⚡ INSTALL ALL BLUEPRINTS (${#BLUEPRINTS[@]} total)"
echo "----------------------------------------------"
for i in "${!BLUEPRINTS[@]}"; do
    printf " [%2d] %s\n" "$((i + 1))" "${BLUEPRINTS[$i]}"
done
echo "----------------------------------------------"
echo ""

read -p "Enter selection (0-${#BLUEPRINTS[@]}): " CHOICE < /dev/tty

if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 0 ] || [ "$CHOICE" -gt "${#BLUEPRINTS[@]}" ]; then
    echo ""
    echo "❌ Invalid selection. Exiting."
    exit 1
fi

download_and_install() {
    local file="$1"
    local identifier="${file%.blueprint}"
    
    # Properly URL-encode characters for curl
    local encoded_file
    encoded_file=$(echo "$file" | jq -sRr @uri | tr -d '\n')
    local raw_url="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/$BRANCH/$encoded_file"

    echo "----------------------------------------------"
    echo "📥 Downloading: $file"
    echo "----------------------------------------------"

    # Download raw file with -L to follow redirects
    curl -sSL -H "User-Agent: Mozilla/5.0" -o "$file" "$raw_url"

    # Verify download is a valid archive, not HTML error text
    if [ ! -s "$file" ] || ! unzip -t "$file" >/dev/null 2>&1; then
        echo "❌ Download failed! $file is corrupted or 404 on GitHub."
        rm -f "$file"
        return 1
    fi

    echo "🚀 Installing: $identifier"
    echo "----------------------------------------------"

    # Run Blueprint installer with clean identifier
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
    echo "✅ All blueprint tasks finished!"
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
