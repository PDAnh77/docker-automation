#!/bin/bash

# --- KIỂM TRA: /usr/bin/dockerd ---
EXPECTED_DOCKERD="-w /usr/bin/dockerd -p rwxa -k docker"
ACTUAL_DOCKERD=$(auditctl -l | grep "/usr/bin/dockerd")

if [[ "$ACTUAL_DOCKERD" == *"$EXPECTED_DOCKERD"* ]]; then
    echo "[PASS] 1.1.3 Auditing is configured for Docker Daemon (/usr/bin/dockerd)"
else
    echo "[FAIL] 1.1.3 Missing audit rule for /usr/bin/dockerd"
    echo "      -> Expected: $EXPECTED_DOCKERD"
    echo "      -> Actual  : $ACTUAL_DOCKERD"
fi

# --- KIỂM TRA: /run/containerd ---
EXPECTED_CONTAINERD="-w /run/containerd -p rwa -k docker"
ACTUAL_CONTAINERD=$(auditctl -l | grep "/run/containerd")

if [[ "$ACTUAL_CONTAINERD" == *"$EXPECTED_CONTAINERD"* ]]; then
    echo "[PASS] 1.1.4 Auditing is configured for Containerd (/run/containerd)"
else
    echo "[FAIL] 1.1.4 Missing audit rule for /run/containerd"
    echo "      -> Expected: $EXPECTED_CONTAINERD"
    echo "      -> Actual  : $ACTUAL_CONTAINERD"
fi

# --- KIỂM TRA: /var/lib/docker ---
# Lấy toàn bộ rule liên quan đến thư mục này
ACTUAL_DOCKER_LIB=$(auditctl -l | grep "/var/lib/docker")

# 3.1 Kiểm tra rule theo dõi chính
REQ_MAIN="-w /var/lib/docker -p rwa -k docker"
if [[ "$ACTUAL_DOCKER_LIB" == *"$REQ_MAIN"* ]]; then
    echo "[PASS] 1.1.5 Auditing is configured for Docker Data Directory"
else
    echo "[FAIL] 1.1.5 Missing audit rule for /var/lib/docker"
    echo "      -> Expected: $REQ_MAIN"
fi

# 3.2 Kiểm tra rule loại trừ volumes
REQ_VOL="-a never,exit -S all -F dir=/var/lib/docker/volumes"
if [[ "$ACTUAL_DOCKER_LIB" == *"$REQ_VOL"* ]]; then
    echo "[PASS] 1.1.5 Exclusion rule configured for Docker Volumes"
else
    echo "[FAIL] 1.1.5 Missing exclusion rule for /var/lib/docker/volumes"
    echo "      -> Expected: $REQ_VOL"
fi

# 3.3 Kiểm tra rule loại trừ overlay2
REQ_OVERLAY="-a never,exit -S all -F dir=/var/lib/docker/overlay2"
if [[ "$ACTUAL_DOCKER_LIB" == *"$REQ_OVERLAY"* ]]; then
    echo "[PASS] 1.1.5 Exclusion rule configured for Docker Overlay2"
else
    echo "[FAIL] 1.1.5 Missing exclusion rule for /var/lib/docker/overlay2"
    echo "      -> Expected: $REQ_OVERLAY"
fi

# --- KIỂM TRA: /run/containerd ---
EXPECTED_CONTAINERD="-w /etc/docker -p rwxa -k docker"
ACTUAL_CONTAINERD=$(auditctl -l | grep "/etc/docker")

if [[ "$ACTUAL_CONTAINERD" == *"$EXPECTED_CONTAINERD"* ]]; then
    echo "[PASS] 1.1.6 Auditing is configured for Docker (/etc/docker)"
else
    echo "[FAIL] 1.1.6 Missing audit rule for /etc/docker"
    echo "      -> Expected: $EXPECTED_CONTAINERD"
    echo "      -> Actual  : $ACTUAL_CONTAINERD"
fi

echo ">>> Complete."