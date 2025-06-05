#!/bin/bash

set -e

# --- Step 1: Install Deskflow ---
echo "🛠 Installing Deskflow..."

if ! command -v deskflow >/dev/null 2>&1; then
    distro=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"')

    case "$distro" in
        ubuntu|debian)
            sudo apt update
            sudo apt install -y deskflow
            ;;
        fedora)
            sudo dnf install -y deskflow
            ;;
        arch)
            sudo pacman -Sy --noconfirm deskflow
            ;;
        *)
            echo "Unsupported distro: $distro. Please install Deskflow manually."
            exit 1
            ;;
    esac
else
    echo "✅ Deskflow already installed."
fi

# --- Step 2: Download config file ---
echo "⬇️ Downloading Deskflow config..."

GITHUB_USER="lolgufdHD"  # <-- Change this
CONFIG_URL="https://raw.githubusercontent.com/$GITHUB_USER/linux-files/main/deskflow/config.yaml"
DEST_DIR="$HOME/.config/deskflow"
DEST_FILE="$DEST_DIR/config.yaml"

mkdir -p "$DEST_DIR"
curl -fsSL "$CONFIG_URL" -o "$DEST_FILE"

echo "✅ Config saved to: $DEST_FILE"

# --- Step 3: Start Deskflow ---
echo "🚀 Starting Deskflow..."
deskflow &

echo "🎉 Deskflow is ready with your custom config."
