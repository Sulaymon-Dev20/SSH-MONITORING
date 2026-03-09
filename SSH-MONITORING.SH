#!/bin/bash

echo "ishladi"

URL="https://script.google.com/macros/s/AKfycbzeHrt9VhbQwo3a1h2XU8VRldoUJncg6QxGR3IJs3EcczMee7hpfTeVCIdTMdkON4TV1w/exec"

START_TIME=$(date +"%Y-%m-%d %T")
MAIN_PID=$$
SSH_USER="$USER"
CLIENT_IP=$(echo "$SSH_CLIENT" | awk '{print $1}')

# Detect server IP
if [[ "$OSTYPE" == "darwin"* ]]; then
    SERVER_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1)
else
    SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
fi

# SSH connection details
if [[ -n "$SSH_CONNECTION" ]]; then
    read REMOTE_IP REMOTE_PORT LOCAL_IP LOCAL_PORT <<< "$SSH_CONNECTION"
    SSH_CONNECTION_JSON="\"$REMOTE_IP:$REMOTE_PORT $LOCAL_IP:$LOCAL_PORT\""
else
    SSH_CONNECTION_JSON="null"
fi

# ================= LOGIN JSON =================
LOGIN_JSON=$(cat <<EOF
{
  "api": "post",
  "server": "$SERVER_IP",
  "time": "$START_TIME",
  "ipv4": "$CLIENT_IP",
  "user": "$SSH_USER",
  "pid": $MAIN_PID,
  "ssh_connection": $SSH_CONNECTION_JSON,
  "active": true
}
EOF
)

# Send login
curl --location "$URL" \
     --header "Content-Type: application/json" \
     --data "$LOGIN_JSON" \
     > /dev/null 2>&1 &

# ================= WATCHDOG =================
(
WATCH_PID=$MAIN_PID

while kill -0 "$WATCH_PID" 2>/dev/null; do
    sleep 20
done

# When PID dies → send logout
END_TIME=$(date +"%Y-%m-%d %T")

LOGOUT_JSON=$(cat <<EOF
{
  "api": "update",
  "server": "$SERVER_IP",
  "time": "$END_TIME",
  "ipv4": "$CLIENT_IP",
  "user": "$SSH_USER",
  "pid": $WATCH_PID,
  "active": false
}
EOF
)

curl --location "$URL" \
     --header "Content-Type: application/json" \
     --data "$LOGOUT_JSON" \
     > /dev/null 2>&1

) &

# ================= START REAL SHELL =================
if [[ -n "$SSH_ORIGINAL_COMMAND" ]]; then
    eval "$SSH_ORIGINAL_COMMAND"
else
    /bin/bash --login
fi
