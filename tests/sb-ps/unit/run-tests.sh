#!/bin/bash
# run-tests.sh - Run sb ps unit tests using Bats
#
# Prerequisites:
#   - bats-core: https://github.com/bats-core/bats-core
#
# Usage:
#   ./run-tests.sh                    # Run all tests
#   ./run-tests.sh <test-file.bats>   # Run specific test file

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TESTS_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BATS="$TESTS_ROOT/tools/bats/bats-core/bin/bats"

if [ ! -x "$BATS" ]; then
    echo "Error: 'bats' not found at '$BATS'. Install bats-core under tests/tools/bats/bats-core/"
    exit 1
fi

if [ $# -gt 0 ]; then
    "$BATS" "$@"
else
    "$BATS" "$SCRIPT_DIR"/*.bats
fi
