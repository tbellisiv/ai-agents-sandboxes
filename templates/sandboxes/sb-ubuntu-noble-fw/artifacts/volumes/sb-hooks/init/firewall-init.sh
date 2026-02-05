#!/bin/bash

SCRIPT_NAME=$(basename "$0")

echo ""
echo "$SCRIPT_NAME: Initializing firewall..."

if [ -x /usr/local/bin/init-firewall.sh ]; then
    sudo /usr/local/bin/init-firewall.sh
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "$SCRIPT_NAME: Firewall initialization failed with exit code $exit_code"
    fi
    exit $exit_code
else
    echo "$SCRIPT_NAME: WARNING: Firewall script not found at /usr/local/bin/init-firewall.sh"
    exit 1
fi
