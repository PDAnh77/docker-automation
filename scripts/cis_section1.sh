#!/bin/bash

# Danh sách Rule chuẩn CIS
RULES=(
    "-w /usr/bin/dockerd -k docker"
    "-a exit,always -F path=/run/containerd -F perm=war -k docker"
    "-a exit,always -F path=/var/lib/docker -F perm=war -k docker"
    "-a exit,never -F dir=/var/lib/docker/volumes"
    "-a exit,never -F dir=/var/lib/docker/overlay2"
    "-w /etc/docker -k docker"
)

AUDIT_FILE="/etc/audit/rules.d/audit.rules"
CHANGED=0

echo ">>> [Ubuntu] Checking CIS Audit Rules..."

# 1. Cài đặt Auditd
if ! command -v auditctl &> /dev/null; then
    echo "[INSTALL] Installing auditd..."
    apt-get update && apt-get install -y auditd audispd-plugins
    CHANGED=1
fi

# 2. Kiểm tra và thêm rule
for RULE in "${RULES[@]}"; do
    # Lấy đường dẫn cần audit
    PATH_TO_CHECK=$(echo "$RULE" | grep -oP '(?<=path=|dir=|-w )/[^ ]+')
    
    if [ -e "$PATH_TO_CHECK" ]; then
        # Kiểm tra trong file đã cấu hình sẵn cho đường dẫn được chỉ định chưa?
        if grep -q "$PATH_TO_CHECK" "$AUDIT_FILE"; then
            echo "[SKIP] Rule for $PATH_TO_CHECK already exists."
        else
            echo "[APPLY] Adding rule for $PATH_TO_CHECK"
            echo "$RULE" >> "$AUDIT_FILE"
            CHANGED=1
        fi
    else
        echo "[IGNORE] Path not found: $PATH_TO_CHECK"
    fi
done

# 3. Restart nếu cần
if [ $CHANGED -eq 1 ]; then
    echo ">>> Restarting Auditd..."
    service auditd restart || systemctl restart auditd
    echo ">>> Complete."
else
    echo ">>> No changes needed."
fi