#!/bin/bash

set -e

SERVICE_NAME="vban-receptor"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# Prompt user for input
read -rp "Enter the IP address of the VBAN source: " ip_address
read -rp "Enter the port number [default: 6980]: " port
port=${port:-6980}

read -rp "Enter the stream name (no spaces): " stream_name

# Final command
VBAN_CMD="/usr/local/bin/vban_receptor --ipaddress=$ip_address --port=$port --streamname=$stream_name --backend=pulseaudio"

# Function to install dependencies and vban_receptor
install_vban_receptor() {
    echo "Installing vban_receptor..."

    # Detect distro
    distro=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"')
    echo "Detected distro: $distro"

    case "$distro" in
        vanilla|ubuntu|debian)
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

    cd /tmp
    git clone https://github.com/quiniouben/vban_receptor.git
    cd vban_receptor
    mkdir -p build && cd build
    cmake ..
    make
    cp vban_receptor /usr/local/bin/
    echo "✅ vban_receptor installed to /usr/local/bin"
}

# Check for vban_receptor
if ! command vban_receptor -v != 0; then
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

echo "✅ VBAN Receptor service created and running."
systemctl status "$SERVICE_NAME" --no-pager
