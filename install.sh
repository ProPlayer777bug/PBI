#!/bin/bash

# =========================================================
#  PBI - Pterodactyl Blueprint CLI Installer
#  Repository: ProPlayer777bug/PBI (Branch: blueprints)
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

# Check if Blueprint CLI exists on the system
if ! command -v blueprint &> /dev/null; then
    echo "⚠️  WARNING: 'blueprint' CLI command is not installed on this system."
    echo "    Make sure you run this script on your Pterodactyl server."
    echo ""
fi

# Ensure required system dependencies are installed
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

# Extract blueprint filenames into array
mapfile -t BLUEPRINTS < <(echo "$RESPONSE" | jq -r '.[] | select(.name | endswith(".blueprint")) | .name')

if [ ${#BLUEPRINTS[@]} -eq 0 ] || [ "${BLUEPRINTS[0]}" == "null" ]; then
    echo "❌ No .blueprint files found in repository '$REPO_USER/$REPO_NAME' on branch '$BRANCH'!"
    exit 1
fi

# Print DevOps style menu options
echo "Select an option:"
echo "----------------------------------------------"
echo " [ 0] ⚡ INSTALL ALL BLUEPRINTS (${#BLUEPRINTS[@]} total)"
echo "----------------------------------------------"
for i in "${!BLUEPRINTS[@]}"; do
    printf " [%2d] %s\n" "$((i + 1))" "${BLUEPRINTS[$i]}"
done
echo "----------------------------------------------"
echo ""

# Prompt for selection (works directly over curl piped to bash)
read -p "Enter selection (0-${#BLUEPRINTS[@]}): " CHOICE < /dev/tty

# Input validation
if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 0 ] || [ "$CHOICE" -gt "${#BLUEPRINTS[@]}" ]; then
    echo ""
    echo "❌ Invalid selection. Please try again."
    exit 1
fi

# Function to download from GitHub and execute installation
download_and_install() {
    local file="$1"
    local raw_url="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/$BRANCH/$file"
    local name="${file%.blueprint}"

    echo "----------------------------------------------"
    echo "📥 Downloading: $file"
    echo "----------------------------------------------"

    curl -sSL -o "$file" "$raw_url"

    if [ ! -s "$file" ]; then
        echo "❌ Download failed or returned empty file for $file"
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

# Option 0: Install ALL
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

# Single Blueprint Option
else
    SELECTED_FILE="${BLUEPRINTS[$((CHOICE - 1))]}"
    
    echo ""
    echo "=============================================="
    echo " 🚀 Installing target: ${SELECTED_FILE%.blueprint}"
    echo "=============================================="
    echo ""

    download_and_install "$SELECTED_FILE"
fi
