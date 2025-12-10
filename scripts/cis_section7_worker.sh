#!/bin/bash

# Nhận tham số từ Ansible
TOKEN=$1
MANAGER_IP=$2
MY_WORKER_IP=$3

echo ">>> [Worker] Checking Swarm Status on $MY_WORKER_IP..."

SWARM_STATUS=$(docker info --format '{{.Swarm.LocalNodeState}}')

if [ "$SWARM_STATUS" == "active" ]; then
    echo "[SKIP] Node is already part of a Swarm."
else
    echo "[JOIN] Joining Swarm..."
    docker swarm join \
      --token "$TOKEN" \
      --advertise-addr "$MY_WORKER_IP" \
      --listen-addr "$MY_WORKER_IP:2377" \
      "$MANAGER_IP:2377"
    
    if [ $? -eq 0 ]; then
        echo "[OK] Successfully joined."
    else
        echo "[FAIL] Could not join Swarm."
        exit 1
    fi
fi

echo ">>> Complete."