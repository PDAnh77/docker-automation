#!/bin/bash
# "true": xóa, "false": chỉ kiểm tra
ENABLE_PRUNE=$1

echo ">>> Starting CIS Section 6: Security Operations Check..."

# --- 6.1 Ensure that image sprawl is avoided ---
echo "--- [6.1] Checking Image Sprawl ---"

# Đếm tổng số image
TOTAL_IMAGES=$(docker images -q | wc -l)
# Đếm số image 'dangling' (không có tag, không được container nào dùng)
DANGLING_IMAGES=$(docker images -f "dangling=true" -q | wc -l)

echo "INFO: Total images present: $TOTAL_IMAGES"
echo "INFO: Dangling images (safe to remove): $DANGLING_IMAGES"

if [ "$ENABLE_PRUNE" == "true" ]; then
    if [ "$DANGLING_IMAGES" -gt 0 ]; then
        echo "ACTION: Pruning dangling images..."
        # Xóa các image dangling
        docker image prune -f
    else
        echo "OK: No dangling images to prune."
    fi
else
    echo "SKIP: Prune disabled. Set variable to 'true' to clean up."
fi

# --- 6.2 Ensure that container sprawl is avoided ---
echo "--- [6.2] Checking Container Sprawl ---"

# Lấy số lượng container đang chạy và đã dừng
RUNNING_CONTAINERS=$(docker info --format '{{.ContainersRunning}}')
STOPPED_CONTAINERS=$(docker info --format '{{.ContainersStopped}}')

echo "INFO: Running containers: $RUNNING_CONTAINERS"
echo "INFO: Stopped containers (potentially unused): $STOPPED_CONTAINERS"

if [ "$ENABLE_PRUNE" == "true" ]; then
    if [ "$STOPPED_CONTAINERS" -gt 0 ]; then
        echo "ACTION: Pruning stopped containers..."
        # Xóa tất cả container đang ở trạng thái Exited
        docker container prune -f
    else
        echo "OK: No stopped containers to prune."
    fi
else
    echo "SKIP: Prune disabled. Set variable to 'true' to clean up."
fi

echo ">>> CIS Section 6 Check Finished."