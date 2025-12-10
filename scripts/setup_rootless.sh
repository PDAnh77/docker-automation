#!/bin/bash
set -e

# Tự động lấy user hiện tại
TARGET_USER=$(whoami)
USER_HOME=$HOME
DOCKER_BIN="$USER_HOME/bin"

echo ">>> [Rootless Setup] Running as user: $TARGET_USER"

# --- ROOT TASKS ---
echo ">>> [System] Installing dependencies & Stopping Root Docker..."

# Cài đặt uidmap
if ! dpkg -l | grep -q uidmap; then
    sudo apt-get update && sudo apt-get install -y uidmap
fi

# Stop & Disable Docker Root
sudo systemctl stop docker.socket docker.service
sudo systemctl disable docker.socket docker.service

# --- USER TASKS (Không sudo) ---

# Cài đặt Docker Rootless
if [ -f "$DOCKER_BIN/dockerd" ]; then
    echo ">>> Docker Rootless binaries found. Skipping download."
else
    echo ">>> Installing Docker Rootless..."
    # Bỏ qua bước kiểm tra socket
    export FORCE_ROOTLESS_INSTALL=1

    curl -fsSL https://get.docker.com/rootless | sh
fi

# Cấu hình .bashrc
BASHRC="$USER_HOME/.bashrc"
echo ">>> Configuring Environment..."

# Hàm thêm dòng an toàn
add_line() {
    grep -qF -- "$1" "$2" || echo "$1" >> "$2"
}

add_line "export PATH=$USER_HOME/bin:\$PATH" "$BASHRC"
add_line "export DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock" "$BASHRC"

# Bật Service Rootless
echo ">>> Starting User Service..."
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
systemctl --user enable docker
systemctl --user start docker

sleep 3
if systemctl --user is-active --quiet docker; then
    echo "Rootless Docker is RUNNING."
else
    echo "Failed. Check logs."
    exit 1
fi