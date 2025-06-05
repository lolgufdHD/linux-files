#!/bin/bash

set -e

# --- Step 1: Install Deskflow ---
echo "Installing Deskflow..."

if ! command -v deskflow >/dev/null 2>&1; then
    distro=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"')

    case "$distro" in
        fedora)
            sudo dnf install -y flatpak
            flatpak install flathub org.deskflow.deskflow
            ;;
        *)
            echo "Unsupported distro: $distro. Please install Deskflow manually."
            exit 1
            ;;
    esac
else
    echo "Deskflow already installed."
fi

# --- Step 2: Download config file ---
echo "Downloading Deskflow config..."

GITHUB_USER="lolgufdHD"  # <-- Change this
CONFIG_URL="https://raw.githubusercontent.com/$GITHUB_USER/linux-files/main/deskflow_config.conf"
DEST_DIR="$HOME/.config/deskflow"
DEST_FILE="$DEST_DIR/deskflow-server.conf"

mkdir -p "$DEST_DIR"
curl -fsSL "$CONFIG_URL" -o "$DEST_FILE"

echo "Config saved to: $DEST_FILE"
