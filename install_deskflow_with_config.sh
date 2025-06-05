#!/bin/bash

set -e

# --- Step 1: Install Deskflow ---
echo "Installing Deskflow..."

sudo dnf install -y flatpak
flatpak install org.deskflow.deskflow

# --- Step 2: Download config file ---
echo "Downloading Deskflow config..."

GITHUB_USER="lolgufdHD"  # <-- Change this
CONFIG_URL="https://raw.githubusercontent.com/$GITHUB_USER/linux-files/main/deskflow_config.conf"
DEST_DIR="$HOME/.config/deskflow"
DEST_FILE="$DEST_DIR/deskflow-server.conf"

mkdir -p "$DEST_DIR"
curl -fsSL "$CONFIG_URL" -o "$DEST_FILE"

echo "Config saved to: $DEST_FILE"
