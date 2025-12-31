#!/bin/bash

echo ">>> [Section 3] Checking File Permissions & Ownership..."

# Hàm kiểm tra và sửa quyền (Idempotency)
# Usage: ensure_file <path> <owner:group> <permissions>
ensure_file() {
    local FILE_PATH=$1
    local TARGET_OWNER=$2
    local TARGET_PERM=$3

    if [ -e "$FILE_PATH" ]; then
        # 1. Kiểm tra Owner
        CURRENT_OWNER=$(stat -c "%U:%G" "$FILE_PATH")
        if [ "$CURRENT_OWNER" != "$TARGET_OWNER" ]; then
            echo "[FIX] $FILE_PATH: Owner $CURRENT_OWNER -> $TARGET_OWNER"
            chown "$TARGET_OWNER" "$FILE_PATH"
        else
            echo "[PASS] $FILE_PATH: Owner is correct ($CURRENT_OWNER)"
        fi

        # 2. Kiểm tra Permissions (So sánh dạng số)
        CURRENT_PERM=$(stat -c "%a" "$FILE_PATH")
        # Nếu quyền hiện tại lỏng hơn quyền mục tiêu (số lớn hơn) thì sửa
        if [ "$CURRENT_PERM" -gt "$TARGET_PERM" ]; then
            echo "[FIX] $FILE_PATH: Perms $CURRENT_PERM -> $TARGET_PERM"
            chmod "$TARGET_PERM" "$FILE_PATH"
        elif [ "$CURRENT_PERM" != "$TARGET_PERM" ]; then
            # Thông báo nếu quyền khác (chặt hơn) nhưng không sửa
            echo "[PASS] $FILE_PATH: Perms $CURRENT_PERM is safe (Target: $TARGET_PERM)"
        else
            echo "[PASS] $FILE_PATH: Perms is correct ($CURRENT_PERM)"
        fi
    else
        echo "[SKIP] File not found: $FILE_PATH"
    fi
}

# --- THỰC THI CIS SECTION 3 ---

# [3.1 & 3.2] docker.service
echo "--- [3.1 & 3.2] docker.service ---"
DOCKER_SERVICE=$(systemctl show -p FragmentPath docker.service | cut -d= -f2)
ensure_file "$DOCKER_SERVICE" "root:root" "644"

# [3.3 & 3.4] docker.socket
echo "--- [3.3 & 3.4] docker.socket ---"
DOCKER_SOCKET_FILE=$(systemctl show -p FragmentPath docker.socket | cut -d= -f2)
ensure_file "$DOCKER_SOCKET_FILE" "root:root" "644"

# [3.5 & 3.6] /etc/docker directory
echo "--- [3.5 & 3.6] /etc/docker ---"
ensure_file "/etc/docker" "root:root" "755"

# [3.7 & 3.8] Registry certificates
echo "--- [3.7 & 3.8] Registry certificates ---"
if [ -d "/etc/docker/certs.d" ]; then
    echo ">>> Checking Registry Certs..."
    find /etc/docker/certs.d -type f | while read file; do
        ensure_file "$file" "root:root" "444"
    done
    ensure_file "/etc/docker/certs.d" "root:root" "755"
fi

# [3.15 & 3.16] Docker Socket
echo "--- [3.15 & 3.16] /var/run/docker.sock ---"
ensure_file "/var/run/docker.sock" "root:docker" "660"

# [3.17 & 3.18] daemon.json
echo "--- [3.17 & 3.18] daemon.json ---"
ensure_file "/etc/docker/daemon.json" "root:root" "644"

# [3.19 & 3.20] /etc/default/docker
echo "--- [3.19 & 3.20] /etc/default/docker ---"
ensure_file "/etc/default/docker" "root:root" "644"

# [3.23 & 3.24] Containerd Socket
echo "--- [3.23 & 3.24] Containerd Socket ---"
ensure_file "/run/containerd/containerd.sock" "root:root" "660"

echo ">>> Complete."