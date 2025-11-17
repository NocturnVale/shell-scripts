#!/bin/bash

# Simple host availability checker - loops until the target responds to ping

echo "Enter the host you want to check (e.g., google.com or 192.168.1.1):"
read -r target

# Basic input validation
if [[ -z "$target" ]]; then
    echo "Error: No target provided."
    exit 1
fi

# Prevent obvious command injection (very basic protection)
if [[ "$target" = *[*;&|\`]* ]]; then
    echo "Error: Invalid characters in target."
    exit 1
fi

echo "Pinging $target until it comes up..."

while true; do
    if ping -q -c 2 -W 1 "$target" > /dev/null 2>&1; then
        echo "$target is UP!"
        break
    else
        echo "$target is still down..."
    fi
    sleep 1
done