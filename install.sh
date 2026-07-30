#!/bin/bash

# =========================================================
#  PBI - Automated Blueprint Downloader & Installer
#  Repository: ProPlayer777bug/PBI (Branch: blueprints)
# =========================================================

REPO_USER="ProPlayer777bug"
REPO_NAME="PBI"
BRANCH="blueprints"

cd "$(pwd)" || exit 1
clear

# 1. Check if Blueprint CLI exists
if ! command -v blueprint &> /dev/null; then
    echo "❌ ERROR: 'blueprint' CLI command is not installed or not in PATH."
    exit 1
fi

# 2. Install required system tools silently if missing
if ! command -v whiptail &> /dev/null || ! command -v jq &> /dev/null; then
    echo "⚙️ Installing required dependencies (whiptail, jq)..."
    if command -v apt-get &> /dev/null; then
        apt-get update -y >/dev/null 2>&1
        apt-get install -y whiptail jq curl >/dev/null 2>&1
    elif command -v yum &> /dev/null; then
        yum install -y newt jq curl >/dev/null 2>&1
    fi
fi

echo "🔍 Fetching blueprint repository contents from GitHub..."

# 3. Fetch list of .blueprint files directly from GitHub's API
API_URL="https://api.github.com/repos/$REPO_USER/$REPO_NAME/contents?ref=$BRANCH"
RESPONSE=$(curl -sSL "$API_URL")

# Parse JSON response using jq to get file names
mapfile -t FILES < <(echo "$RESPONSE" | jq -r '.[] | select(.name | endswith(".blueprint")) | .name')

if [ ${#FILES[@]} -eq 0 ] || [ "${FILES[0]}" == "null" ]; then
    clear
    echo "❌ No .blueprint files found in repository '$REPO_USER/$REPO_NAME' on branch '$BRANCH'!"
    exit 1
fi

# 4. Build GUI Menu Options
MENU_ITEMS=("0" "⚡ INSTALL ALL (${#FILES[@]} total)")
for i in "${!FILES[@]}"; do
    MENU_ITEMS+=("$((i + 1))" "${FILES[$i]}")
done

# 5. Display Interactive Terminal Menu
CHOICE=$(whiptail --clear \
    --backtitle "Pterodactyl Blueprint GUI Installer" \
    --title " Select Blueprint to Download & Install " \
    --menu "Use UP/DOWN arrow keys and press ENTER to select:" 18 70 10 \
    "${MENU_ITEMS[@]}" \
    3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
    clear
    echo "Installation cancelled."
    exit 0
fi

clear

# 6. Helper function to download from GitHub and install locally
download_and_install() {
    local filename="$1"
    local raw_url="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/$BRANCH/$filename"
    local blueprint_name="${filename%.blueprint}"

    echo "=============================================="
    echo " 📥 Downloading from GitHub: $filename"
    echo "=============================================="
    
    curl -sSL -o "$filename" "$raw_url"

    if [ ! -s "$filename" ]; then
        echo "❌ Download failed or returned empty file for $filename"
        rm -f "$filename"
        return 1
    fi

    echo ""
    echo "=============================================="
    echo " 🚀 Auto-Installing: $blueprint_name"
    echo "=============================================="

    # Auto-answer prompts with yes
    if yes | blueprint -install "$blueprint_name"; then
        echo "✅ Successfully installed: $blueprint_name"
        rm -f "$filename"
    else
        echo "❌ Installation failed for $blueprint_name"
        rm -f "$filename"
        return 1
    fi
    echo ""
}

# 7. Run selection logic
if [ "$CHOICE" -eq 0 ]; then
    echo "🚀 Starting batch download & installation..."
    echo ""
    for file in "${FILES[@]}"; do
        download_and_install "$file"
    done
    echo "=============================================="
    echo "✅ All blueprints downloaded & installed successfully!"
    echo "=============================================="
else
    INDEX=$((CHOICE - 1))
    TARGET_FILE="${FILES[$INDEX]}"
    download_and_install "$TARGET_FILE"
fi
