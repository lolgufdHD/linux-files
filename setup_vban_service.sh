#!/bin/bash

set -euo pipefail

SERVICE_NAME="vban-receptor"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
VBAN_BINARY="/usr/local/bin/vban_receptor"
REPO_DIR="/tmp/vban_receptor"
REPO_URL="https://github.com/quiniouben/vban_receptor.git"

###############################################################################
# Root check
###############################################################################

if [[ $EUID -ne 0 ]]; then
    echo "Dieses Script muss mit sudo ausgeführt werden:"
    echo "  sudo $0"
    exit 1
fi

###############################################################################
# Determine the real desktop user
###############################################################################

if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    RUN_USER="$SUDO_USER"
else
    RUN_USER="$(logname 2>/dev/null || true)"
fi

if [[ -z "$RUN_USER" || "$RUN_USER" == "root" ]]; then
    echo "Fehler: Konnte den normalen Benutzer nicht ermitteln."
    echo "Bitte das Script mit 'sudo' ausführen."
    exit 1
fi

RUN_UID="$(id -u "$RUN_USER")"
RUN_HOME="$(getent passwd "$RUN_USER" | cut -d: -f6)"

if [[ -z "$RUN_HOME" ]]; then
    echo "Fehler: Home-Verzeichnis von $RUN_USER konnte nicht ermittelt werden."
    exit 1
fi

echo "Benutzer für den Audio-Service: $RUN_USER"

###############################################################################
# User input
###############################################################################

read -rp "Enter the IP address of the VBAN source: " ip_address

if [[ ! "$ip_address" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "Fehler: Ungültige IPv4-Adresse: $ip_address"
    exit 1
fi

read -rp "Enter the port number [default: 6980]: " port
port="${port:-6980}"

if [[ ! "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
    echo "Fehler: Ungültiger Port: $port"
    exit 1
fi

read -rp "Enter the stream name (no spaces): " stream_name

if [[ -z "$stream_name" || "$stream_name" =~ [[:space:]] ]]; then
    echo "Fehler: Der Streamname darf nicht leer sein und keine Leerzeichen enthalten."
    exit 1
fi

###############################################################################
# Detect distribution
###############################################################################

distro="$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"')"

echo "Detected distro: $distro"

###############################################################################
# Install dependencies
###############################################################################

install_dependencies() {

    echo
    echo "Installing dependencies..."

    case "$distro" in

        ubuntu|debian)
            apt update
            apt install -y \
                build-essential \
                git \
                cmake \
                libpulse-dev \
                libasound2-dev
            ;;

        fedora)
            dnf install -y \
                gcc \
                gcc-c++ \
                git \
                cmake \
                pkgconf-pkg-config \
                pulseaudio-libs-devel \
                alsa-lib-devel
            ;;

        arch|cachyos)
            pacman -Sy --noconfirm \
                base-devel \
                git \
                cmake \
                pkgconf \
                alsa-lib \
                libpulse
            ;;

        *)
            echo
            echo "Unsupported distro: $distro"
            echo "Unterstützte Distributionen:"
            echo "  Ubuntu"
            echo "  Debian"
            echo "  Fedora"
            echo "  Arch"
            echo "  CachyOS"
            exit 1
            ;;
    esac
}

###############################################################################
# Build vban_receptor
###############################################################################

install_vban_receptor() {

    install_dependencies

    echo
    echo "Building vban_receptor..."

    # Remove previous incomplete source tree.
    if [[ -d "$REPO_DIR" ]]; then
        echo "Removing previous source directory..."
        rm -rf "$REPO_DIR"
    fi

    git clone "$REPO_URL" "$REPO_DIR"

    cd "$REPO_DIR"

    rm -rf build
    mkdir -p build
    cd build

    echo
    echo "Configuring CMake..."

    # We only need PulseAudio.
    # ALSA is left enabled because the project expects it by default.
    # JACK is explicitly disabled because it is not needed.
    cmake \
        -DWITH_JACK=No \
        ..

    echo
    echo "Compiling..."

    make -j"$(nproc)"

    echo
    echo "Installing binary..."

    install -m 0755 vban_receptor "$VBAN_BINARY"

    echo
    echo "vban_receptor installed to:"
    echo "$VBAN_BINARY"
}

###############################################################################
# Check / install vban_receptor
###############################################################################

if [[ ! -x "$VBAN_BINARY" ]]; then

    echo
    echo "vban_receptor is not installed."
    install_vban_receptor

else

    echo
    echo "vban_receptor already installed:"
    echo "$VBAN_BINARY"

fi

###############################################################################
# Check PulseAudio / PipeWire environment
###############################################################################

echo
echo "Checking audio environment..."

USER_RUNTIME_DIR="/run/user/$RUN_UID"

if [[ ! -d "$USER_RUNTIME_DIR" ]]; then
    echo
    echo "WARNUNG:"
    echo "Die Benutzer-Runtime-Session existiert momentan nicht:"
    echo "$USER_RUNTIME_DIR"
    echo
    echo "Der systemd-Service wird trotzdem erstellt."
    echo "Er kann erst funktionieren, wenn die Benutzer-Session läuft."
fi

###############################################################################
# Create systemd service
###############################################################################

echo
echo "Creating systemd service..."

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=VBAN Receptor Audio Stream
Wants=network-online.target
After=network-online.target

[Service]
Type=simple

User=$RUN_USER
Group=$(id -gn "$RUN_USER")

ExecStart=$VBAN_BINARY --ipaddress=$ip_address --port=$port --streamname=$stream_name --backend=pulseaudio

Restart=on-failure
RestartSec=5

# PipeWire/PulseAudio user session
Environment=XDG_RUNTIME_DIR=/run/user/$RUN_UID
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$RUN_UID/bus

# Give the service access to the user's runtime directory
RuntimeDirectory=

[Install]
WantedBy=multi-user.target
EOF

chmod 0644 "$SERVICE_FILE"

###############################################################################
# Enable / start service
###############################################################################

echo
echo "Reloading systemd..."

systemctl daemon-reload

echo
echo "Enabling service..."

systemctl enable "$SERVICE_NAME"

echo
echo "Starting service..."

systemctl restart "$SERVICE_NAME"

###############################################################################
# Show status
###############################################################################

echo
echo "============================================================"
echo "VBAN Receptor service status"
echo "============================================================"
echo

systemctl status "$SERVICE_NAME" --no-pager

echo
echo "============================================================"
echo "Configuration"
echo "============================================================"
echo "Source IP : $ip_address"
echo "Port      : $port"
echo "Stream    : $stream_name"
echo "Backend   : pulseaudio"
echo "User      : $RUN_USER"
echo "Binary    : $VBAN_BINARY"
echo "Service   : $SERVICE_FILE"
echo "============================================================"
