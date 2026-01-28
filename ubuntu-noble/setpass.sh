#!/bin/bash
set -e
cd "$(dirname "$0")"
command -v openssl > /dev/null || {
    echo "Error: openssl not found"
    exit 1
}

[ -f .env ] || cp .env.example .env

read -sp "Enter devcontainer root password: " pass && echo
hash=$(openssl passwd -6 "$pass" | sed 's/\$/\$\$/g')

grep -v "^SUHASH=" .env > .env.tmp && mv .env.tmp .env
echo "SUHASH=$hash" >> .env

echo "Password hash written to .env"
