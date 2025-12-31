#!/bin/bash

# --- 2.2 KIỂM TRA: ICC ---
# Lấy thông tin options của tất cả network
FULL_OUTPUT=$(docker network ls --quiet | xargs docker network inspect --format '{{ .Name}}: {{ .Options }}')

# Lọc ra cấu hình của network bridge
BRIDGE_CONFIG=$(echo "$FULL_OUTPUT" | grep "^bridge:")

# Định nghĩa chuỗi com.docker.network.bridge.enable_icc:false phải có
EXPECTED_ICC="com.docker.network.bridge.enable_icc:false"

if [[ "$BRIDGE_CONFIG" == *"$EXPECTED_ICC"* ]]; then
    echo "[PASS] 2.2 ICC is disabled on default bridge network."
else
    echo "[FAIL] 2.2 ICC is NOT disabled on default bridge network."
    echo "      -> Expected: $EXPECTED_ICC"
    echo "      -> Actual  : $BRIDGE_CONFIG"
fi

# --- 2.3 KIỂM TRA: Log Level ---
# Dùng 2>/dev/null để ẩn lỗi nếu file không tồn tại (coi như rỗng)
LOG_LEVEL_OUTPUT=$(grep "log-level" /etc/docker/daemon.json 2>/dev/null)

if [[ -z "$LOG_LEVEL_OUTPUT" ]] || [[ "$LOG_LEVEL_OUTPUT" == *"info"* ]]; then
    echo "[PASS] 2.3 Log level config is compliant (Default/Info)."
else
    echo "[FAIL] 2.3 Log level config is NOT 'info'."
    echo "      -> Actual: $LOG_LEVEL_OUTPUT"
fi

# --- 2.4 KIỂM TRA: IPtables ---
IPTABLES_OUTPUT=$(grep "iptables" /etc/docker/daemon.json 2>/dev/null)

if [[ -z "$IPTABLES_OUTPUT" ]] || [[ "$IPTABLES_OUTPUT" == *"true"* ]]; then
    echo "[PASS] 2.4 IPtables config is compliant (Default/True)."
else
    echo "[FAIL] 2.4 IPtables config is NOT 'true'."
    echo "      -> Actual: $IPTABLES_OUTPUT"
fi

# --- 2.5 KIỂM TRA: Insecure Registries ---
REGISTRY_OUTPUT=$(docker info --format '{{json .RegistryConfig.InsecureRegistryCIDRs}}')

if [[ "$REGISTRY_OUTPUT" == '["127.0.0.0/8"]' ]] || \
   [[ "$REGISTRY_OUTPUT" == '[]' ]] || \
   [[ "$REGISTRY_OUTPUT" == *'"::1/128"'* && "$REGISTRY_OUTPUT" == *'"127.0.0.0/8"'* ]]; then
    echo "[PASS] 2.5 No insecure registries defined."
else
    echo "[FAIL] 2.5 Insecure registries detected!"
    echo "      -> Actual: $REGISTRY_OUTPUT"
fi

# --- 2.6 & 2.7 KIỂM TRA: Storage Driver (AUFS) & Storage Driver (DeviceMapper)---
CURRENT_DRIVER=$(docker info --format '{{ .Driver }}')

if [[ "$CURRENT_DRIVER" == "aufs" ]]; then
    echo "[FAIL] 2.6 System is using 'aufs' storage driver."
else
    echo "[PASS] 2.6 Storage driver is compliant."
    echo "      -> Current Driver: $CURRENT_DRIVER"
fi

if [[ "$CURRENT_DRIVER" == "devicemapper" ]]; then
    echo "[FAIL] 2.7 System is using 'devicemapper' storage driver."
else
    echo "[PASS] 2.7 System is not using 'devicemapper'."
    echo "      -> Current Driver: $CURRENT_DRIVER"
fi

# --- 2.9 KIỂM TRA: Container Ulimits ---
# Lấy danh sách ID và Tên container
CONTAINERS=$(docker ps --format "{{.ID}}|{{.Names}}")
CONTAINER_CHECK=false

if [ -n "$CONTAINERS" ]; then
    # Lặp qua từng container
    echo "$CONTAINERS" | while IFS='|' read -r CONTAINER_ID CONTAINER_NAME; do
        # Đọc file limits trực tiếp từ trong container
        LIMITS_CONTENT=$(docker exec "$CONTAINER_ID" cat /proc/1/limits 2>/dev/null)

        if [ -z "$LIMITS_CONTENT" ]; then
            echo -e "[SKIP] 2.9 Unable to read /proc/1/limits (Container might be stopped or restricted)."
        else
            # Tìm Max open files
            OPEN_FILES=$(echo "$LIMITS_CONTENT" | grep "Max open files")
            # Tìm Max processes
            MAX_PROCS=$(echo "$LIMITS_CONTENT" | grep "Max processes")

            # Sử dụng awk trên Host để lấy cột Soft và Hard
            # Format file limits: Tên | Soft Limit | Hard Limit | Units
            F_SOFT=$(echo "$OPEN_FILES" | awk '{print $(NF-2)}')
            F_HARD=$(echo "$OPEN_FILES" | awk '{print $(NF-1)}')
            
            P_SOFT=$(echo "$MAX_PROCS" | awk '{print $(NF-2)}')
            P_HARD=$(echo "$MAX_PROCS" | awk '{print $(NF-1)}')

            # Nếu bất kỳ biến nào bằng chữ "unlimited" -> FAIL
            if [ "$F_SOFT" == "unlimited" ] || [ "$F_HARD" == "unlimited" ] || \
               [ "$P_SOFT" == "unlimited" ] || [ "$P_HARD" == "unlimited" ]; then
                echo -e "[FAIL] 2.9 Strict limit required for $CONTAINER_NAME."
            else
                echo "[PASS] 2.9 Ulimits is correctly set for $CONTAINER_NAME."
            fi
            # Hiển thị kết quả
            echo "      -> Open Files (nofile): Soft=$F_SOFT | Hard=$F_HARD"
            echo "      -> Processes (nproc)  : Soft=$P_SOFT | Hard=$P_HARD"
        fi
    done

else
    echo "[SKIP] 2.9 No running containers found when checking Ulimits config."
fi

# --- 2.14 KIỂM TRA: Logging Driver ---
CURRENT_LOGGING=$(docker info --format '{{ .LoggingDriver }}')

if [[ "$CURRENT_LOGGING" == "syslog" ]]; then
    echo "[PASS] 2.14 Logging driver configured."
    echo "      -> Current Driver: $CURRENT_LOGGING"
else
    echo "[FAIL] 2.14 Logging driver is not 'syslog'."
    echo "      -> Expected: syslog"
    echo "      -> Actual  : $CURRENT_LOGGING"
fi

# --- 2.15 KIỂM TRA: No New Privileges ---
if [ -n "$CONTAINERS" ]; then
    # Lặp qua từng container để kiểm tra
    echo "$CONTAINERS" | while IFS='|' read -r CONTAINER_ID CONTAINER_NAME; do
        # Kiểm tra file status bên trong container
        STATUS_OUTPUT=$(docker exec "$CONTAINER_ID" grep NoNewPrivs /proc/1/status 2>/dev/null)

        # Phải chứa "1"
        if [[ "$STATUS_OUTPUT" == *"1"* ]]; then
            echo "[PASS] 2.15 NoNewPrivs is correctly set for $CONTAINER_NAME."
        else
            echo "[FAIL] 2.15 Container $CONTAINER_NAME is NOT restricted from acquiring new privileges."
            echo "      -> Expected: NoNewPrivs: 1"
            
            if [ -z "$STATUS_OUTPUT" ]; then
                echo "      -> Actual  : N/A (Could not read /proc/1/status)"
            else
                echo "      -> Actual  : $STATUS_OUTPUT"
            fi
        fi
    done
else
    echo "[SKIP] 2.15 No running containers found when checking NoNewPrivs config."
fi

# --- 2.17 KIỂM TRA: Userland Proxy ---
PROXY_PROCESS=$(ps aux | grep "docker-proxy" | grep -v grep)

# Nếu rỗng (-z) => không có tiến trình
if [ -z "$PROXY_PROCESS" ]; then
    echo "[PASS] 2.17 Userland proxy is disabled."
else
    PROXY_COUNT=$(echo "$PROXY_PROCESS" | wc -l)
    echo "[FAIL] 2.17 Userland proxy is currently running. ($PROXY_COUNT processes found)"
fi

# --- 2.19 KIỂM TRA: Experimental Features ---
EXP_STATUS=$(docker version --format '{{ .Server.Experimental }}' 2>/dev/null)

if [ "$EXP_STATUS" == "false" ]; then
    echo "[PASS] 2.19 Experimental features are disabled."
else
    echo "[FAIL] 2.19 Experimental features are ENABLED."
    echo "      -> Expected: false"
    echo "      -> Actual  : $EXP_STATUS"
fi

echo ">>> Complete."