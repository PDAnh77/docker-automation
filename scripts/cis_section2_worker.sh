#!/bin/bash

SYSLOG_SERVER_IP="$1" # Nhận manager IP
if [ -z "$SYSLOG_SERVER_IP" ]; then
  echo "Error: Syslog Server IP is missing."
  exit 1
fi

CONFIG_DIR="/etc/docker"
DAEMON_FILE="$CONFIG_DIR/daemon.json"
mkdir -p "$CONFIG_DIR"

# Cài đặt jq
if ! command -v jq &> /dev/null; then
    echo "Installing jq..."
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y jq
    fi
fi

# Khởi tạo file JSON rỗng nếu chưa có
if [ ! -f "$DAEMON_FILE" ] || [ ! -s "$DAEMON_FILE" ]; then
    echo "{}" > "$DAEMON_FILE"
fi

# Tạo file tạm
TEMP_FILE=$(mktemp)
cp "$DAEMON_FILE" "$TEMP_FILE"

CHANGE_DETECTED=0 # Cờ theo dõi thay đổi

# --- HÀM XỬ LÝ KIỂM TRA & CẬP NHẬT ---
apply_config() {
    local key_path=$1      
    local raw_new_value=$2 # Giá trị thô truyền vào

    # Đọc giá trị tại key đó trong file tạm
    local current_value
    current_value=$(jq -c "$key_path" "$TEMP_FILE")

    # Chuẩn hóa giá trị mới
    local new_value_json
    new_value_json=$(echo "$raw_new_value" | jq -c '.')

    if [ -z "$current_value" ]; then
        # Trường hợp chưa tồn tại key này
        echo "[ADD] $key_path = $new_value_json"
        # Ghi vào file tạm
        jq "$key_path = $new_value_json" "$TEMP_FILE" > "$TEMP_FILE.tmp" && mv "$TEMP_FILE.tmp" "$TEMP_FILE"
        CHANGE_DETECTED=1
    elif [ "$current_value" != "$new_value_json" ]; then
        # Trường hợp đã tồn tại nhưng khác giá trị
        echo "[UPDATE] $key_path: $current_value -> $new_value_json"
        # Ghi vào file tạm
        jq "$key_path = $new_value_json" "$TEMP_FILE" > "$TEMP_FILE.tmp" && mv "$TEMP_FILE.tmp" "$TEMP_FILE"
        CHANGE_DETECTED=1
    else
        echo "[SKIP] $key_path matches." 
    fi
}

echo ">>> Checking Docker Configuration..."

# --- ĐỊNH NGHĨA CÁC CẤU HÌNH ---
apply_config '.["icc"]' 'false'
apply_config '.["no-new-privileges"]' 'true'
apply_config '.["userland-proxy"]' 'false'
apply_config '.["log-driver"]' '"syslog"'
apply_config '.["log-opts"]["syslog-address"]' "\"tcp://$SYSLOG_SERVER_IP:514\""
apply_config '.["default-ulimits"]["nofile"]' '{ "Name": "nofile", "Hard": 64000, "Soft": 64000 }'
apply_config '.["default-ulimits"]["nproc"]' '{ "Name": "nproc", "Hard": 2048, "Soft": 1024 }'

# --- KẾT THÚC ---
if [ "$CHANGE_DETECTED" -eq 1 ]; then
    # Ghi đè file gốc bằng file tạm đã update
    mv "$TEMP_FILE" "$DAEMON_FILE"
    
    echo ">>> Changes detected. Restarting Docker..."
    systemctl restart docker
    echo ">>> Complete."
else
    echo ">>> No changes needed."
    rm "$TEMP_FILE"
fi