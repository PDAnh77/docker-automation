#!/bin/bash

RSYSLOG_CONF="/etc/rsyslog.conf"
CHANGED=0

echo ">>> [Manager] Checking Rsyslog configuration..."

# Hàm kiểm tra và uncomment
ensure_uncommented() {
    local SEARCH_STR="$1"
    # Kiểm tra nội dung có đang bị comment không
    if grep -q "^#.*$SEARCH_STR" "$RSYSLOG_CONF"; then
        # Thực hiện uncomment
        sed -i "/$SEARCH_STR/s/^#//g" "$RSYSLOG_CONF"
        echo ">>> [UPDATE] $SEARCH_STR"
        CHANGED=1
    elif grep -q "^$SEARCH_STR" "$RSYSLOG_CONF"; then
        echo ">>> [SKIP] $SEARCH_STR already enabled."
    else
        echo ">>> [WARNING] String '$SEARCH_STR' not found in config."
    fi
}

# Kiểm tra module và type port
ensure_uncommented 'module(load="imtcp")'
ensure_uncommented 'input(type="imtcp" port="514")'

if [ "$CHANGED" -eq 1 ]; then
    echo ">>> Restarting rsyslog..."
    systemctl restart rsyslog
    echo ">>> Complete."
else
    echo ">>> No changes needed."
fi