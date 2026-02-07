#!/bin/bash
# run-tests.sh - Run sync unit tests using Bats
#
# Prerequisites:
#   - bats-core: https://github.com/bats-core/bats-core
#
# Usage:
#   ./run-tests.sh                    # Run all tests
#   ./run-tests.sh <test-file.bats>   # Run specific test file

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if ! command -v bats &> /dev/null; then
    echo "Error: 'bats' is not installed. Install bats-core: https://github.com/bats-core/bats-core"
    exit 1
fi

if [ $# -gt 0 ]; then
    bats "$@"
else
    bats "$SCRIPT_DIR"/*.bats
fi
