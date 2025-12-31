#!/bin/bash

ENV_FILE="./.env"

# Kiểm tra file .env có tồn tại không
if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: .env file not found at $ENV_FILE"
    exit 1
fi

echo ">>> 7.4 Starting Docker Secret creation from $ENV_FILE..."

while IFS= read -r line || [ -n "$line" ]; do
    # Bỏ qua dòng trống và comment
    if [[ -z "$line" ]] || [[ "$line" == \#* ]]; then
        continue
    fi

    # Tách Key và Value dựa trên dấu bằng '=' đầu tiên
    RAW_KEY=$(echo "$line" | cut -d '=' -f 1)
    RAW_VALUE=$(echo "$line" | cut -d '=' -f 2-)

    # Bỏ khoảng trắng thừa ở Key
    KEY=$(echo "$RAW_KEY" | xargs)
    
    # Chuyển Key thành chữ thường (DATABASE_URL -> database_url)
    SECRET_NAME=$(echo "$KEY" | tr '[:upper:]' '[:lower:]')

    # Loại bỏ dấu (') hoặc (") bao quanh Value nếu có
    # Ví dụ: "my-secret-value" -> my-secret-value
    SECRET_VALUE=$(echo "$RAW_VALUE" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")

    # Kiểm tra Secret đã tồn tại trong Swarm chưa
    if docker secret inspect "$SECRET_NAME" > /dev/null 2>&1; then
        echo "WARNING: Secret '$SECRET_NAME' already exists. Skipping creation."
    else
        # Tạo Secret
        # Ẩn output thực tế của value để bảo mật
        printf "%s" "$SECRET_VALUE" | docker secret create "$SECRET_NAME" - > /dev/null
        
        if [ $? -eq 0 ]; then
            echo "SUCCESS: Created secret: $SECRET_NAME (from $KEY)"
        else
            echo "ERROR: Failed to create secret: $SECRET_NAME"
        fi
    fi

done < "$ENV_FILE"

echo ">>> Docker Secret creation finished."
echo ">>> Current secret list:"
docker secret ls
echo ">>> Complete."