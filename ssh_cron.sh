#!/bin/bash

DIR="/etc/ssh/.ssh-monitoring"
API_URL="https://your-api.com/endpoint"

[ -d "$DIR" ] || exit 0

for file in "$DIR"/*.txt; do
    [ -e "$file" ] || continue

    pid="${file##*/}"
    pid="${pid%.txt}"

    # skip non-numeric names
    [[ "$pid" =~ ^[0-9]+$ ]] || continue

    # if process still running → skip
    if ps -p "$pid" > /dev/null 2>&1; then
        continue
    fi

    # send file to API
    response=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        --data-binary @"$file")

    # if API success → delete file
    if [ "$response" = "200" ] || [ "$response" = "201" ]; then
        rm -f "$file"
    fi

done
