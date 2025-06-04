#!/bin/bash

set -e

SERVICE_NAME="vban-receptor"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
VBAN_CMD="/usr/local/bin/vban_receptor --ipaddress=192.168.1.21 --port=6980 --streamname=Stream1 --backend=pulseaudio"

# Function to install dependencies and vban_receptor
install_vban_receptor() {
    echo "Installing vban_receptor..."

    # Detect distro
    distro=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"')

    echo "Detected distro: $distro"
    echo "Installing dependencies..."

    case "$distro" in
        ubuntu|debian)
            apt update
            apt install -y build-essential git cmake libpulse-dev
            ;;
        fedora)
            dnf install -y gcc gcc-c++ git cmake pulseaudio-libs-devel
            ;;
        arch)
            pacman -Sy --noconfirm base-devel git cmake pulseaudio
            ;;
        *)
            echo "Unsupported distro: $distro"
            exit 1
            ;;
    esac

    # Clone and build vban_receptor
    cd /tmp
    git clone https://github.com/quiniouben/vban_receptor.git
    cd vban_receptor
    mkdir build && cd build
    cmake ..
    make
    cp vban_receptor /usr/local/bin/

    echo "vban_receptor installed successfully."
}

# Check for vban_receptor
if ! command -v vban_receptor >/dev/null 2>&1; then
    install_vban_receptor
else
    echo "vban_receptor already installed."
fi

# Create systemd service
echo "Creating systemd service..."

cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=VBAN Receptor Audio Stream
After=network.target sound.target

[Service]
ExecStart=$VBAN_CMD
Restart=always
User=$(whoami)

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
echo "Enabling and starting service..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME"

echo "Service status:"
systemctl status "$SERVICE_NAME" --no-pager

echo "✅ VBAN Receptor is now running as a service."
