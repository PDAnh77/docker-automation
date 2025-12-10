#!/bin/bash

# IP của máy Manager (do Ansible truyền vào)
MANAGER_IP=$1

echo ">>> [Manager] Checking Swarm Status on $MANAGER_IP..."

# 1. Khởi tạo Swarm (CIS 7.1, 7.2, 7.5)
SWARM_STATUS=$(docker info --format '{{.Swarm.LocalNodeState}}')

if [ "$SWARM_STATUS" != "active" ]; then
    echo "[INIT] Initializing Docker Swarm..."
    docker swarm init \
      --advertise-addr "$MANAGER_IP" \
      --listen-addr "$MANAGER_IP:2377" \
      --autolock
else
    echo "[SKIP] Swarm is already active."
fi

# 2. Cấu hình bổ sung (CIS 7.7)
CURRENT_EXPIRY=$(docker info --format '{{.Swarm.Cluster.Spec.CAConfig.NodeCertExpiry}}')
if [[ "$CURRENT_EXPIRY" != "720h0m0s" ]]; then
    echo "[APPLY] CIS 7.7: Setting Node Cert Expiry to 720h..."
    docker swarm update --cert-expiry 720h
fi

# 3. Đảm bảo Autolock (CIS 7.5)
AUTOLOCK=$(docker info --format '{{.Swarm.Cluster.Spec.EncryptionConfig.AutoLockManagers}}')
if [ "$AUTOLOCK" == "false" ]; then
    echo "[APPLY] CIS 7.5: Enabling Autolock..."
    docker swarm update --autolock=true
fi

# 4. Xuất Unlock key và Token
UNLOCK_KEY=$(docker swarm unlock-key -q)
echo "UNLOCK_KEY:$UNLOCK_KEY"

WORKER_TOKEN=$(docker swarm join-token -q worker)
echo "JOIN_TOKEN:$WORKER_TOKEN"

echo ">>> Complete."