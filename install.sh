#!/bin/bash

# =========================================================
#  PBI - Automated Blueprint Installer
#  Repository: ProPlayer777bug/PBI (Branch: blueprints)
# =========================================================

REPO_USER="ProPlayer777bug"
REPO_NAME="PBI"
BRANCH="blueprints"

# Set working directory to current path
cd "$(pwd)" || exit 1

clear

# Check if Blueprint CLI is installed
if ! command -v blueprint &> /dev/null; then
    echo "❌ ERROR: 'blueprint' CLI command is not installed or not in PATH."
    exit 1
fi

# Ensure whiptail and jq are available
if ! command -v whiptail &> /dev/null || ! command -v jq &> /dev/null; then
    echo "⚙️ Installing required dependencies (whiptail, jq, curl)..."
    if command -v apt-get &> /dev/null; then
        apt-get update -y && apt-get install -y whiptail jq curl
    elif command -v yum &> /dev/null; then
        yum install -y newt jq curl
    fi
fi

# Optional GitHub Token input for private repos
TOKEN="${GITHUB_TOKEN:-}"

# Prepare authorization header if token is provided
AUTH_HEADER=()
RAW_AUTH_HEADER=()
if [ -n "$TOKEN" ]; then
    AUTH_HEADER=(-H "Authorization: token $TOKEN")
    RAW_AUTH_HEADER=(-H "Authorization: token $TOKEN")
fi

echo "🔍 Fetching available blueprint files from repository..."

# Fetch file list from GitHub API
API_URL="https://api.github.com/repos/$REPO_USER/$REPO_NAME/contents?ref=$BRANCH"
RESPONSE=$(curl -sSL "${AUTH_HEADER[@]}" "$API_URL")

# Extract all .blueprint files from API JSON response
mapfile -t FILES < <(echo "$RESPONSE" | jq -r '.[] | select(.name | endswith(".blueprint")) | .name')

if [ ${#FILES[@]} -eq 0 ]; then
    clear
    echo "❌ No .blueprint files found in repository '$REPO_USER/$REPO_NAME' on branch '$BRANCH'!"
    exit 1
fi

# Build GUI Menu Options
MENU_ITEMS=("0" "⚡ INSTALL ALL (${#FILES[@]} total)")

for i in "${!FILES[@]}"; do
    MENU_ITEMS+=("$((i + 1))" "${FILES[$i]}")
done

# Show Arrow-Key GUI Selection Menu
CHOICE=$(whiptail --clear \
    --backtitle "Pterodactyl Blueprint GUI Installer" \
    --title " Select Blueprint to Download & Install " \
    --menu "Use UP/DOWN arrows and press ENTER to select:" 18 70 10 \
    "${MENU_ITEMS[@]}" \
    3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
    clear
    echo "Installation cancelled."
    exit 0
fi

clear

# Function to download and run installation
download_and_install() {
    local filename="$1"
    local raw_url="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/$BRANCH/$filename"
    local blueprint_name="${filename%.blueprint}"

    echo "=============================================="
    echo " 📥 Downloading: $filename"
    echo "=============================================="
    
    curl -sSL "${RAW_AUTH_HEADER[@]}" -o "$filename" "$raw_url"

    if [ ! -s "$filename" ]; then
        echo "❌ Failed to download $filename (File empty or 404)"
        rm -f "$filename"
        return 1
    fi

    echo ""
    echo "=============================================="
    echo " 🚀 Installing: $blueprint_name"
    echo "=============================================="

    if yes | blueprint -install "$blueprint_name"; then
        echo "✅ Installed: $blueprint_name"
        rm -f "$filename"
    else
        echo "❌ Installation failed for $blueprint_name"
        rm -f "$filename"
        return 1
    fi
    echo ""
}

# Process User Choice
if [ "$CHOICE" -eq 0 ]; then
    echo "🚀 Starting download and batch installation of all blueprints..."
    echo ""
    for file in "${FILES[@]}"; do
        download_and_install "$file"
    done
    echo "=============================================="
    echo "✅ All blueprints installed successfully!"
    echo "=============================================="
else
    INDEX=$((CHOICE - 1))
    TARGET_FILE="${FILES[$INDEX]}"
    download_and_install "$TARGET_FILE"
fi
