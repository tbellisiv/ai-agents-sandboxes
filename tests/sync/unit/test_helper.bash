#!/bin/bash
# test_helper.bash - Shared helper functions for sync unit tests

# Resolve the absolute path to the project root (three levels up from this file)
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$TESTS_DIR/../../.." && pwd)"
SB_SCRIPT="$PROJECT_ROOT/bin/sb"

# SCRIPT_NAME is used by the functions sourced from bin/sb
SCRIPT_NAME="sb"

# Source only the helper functions from bin/sb
# We extract them by sourcing the file in a subshell-safe way
source_sb_helpers() {
    # Source the getoptions lib first (required by bin/sb)
    local lib_dir="$PROJECT_ROOT/lib"
    local getoptions_lib_path="$lib_dir/getoptions_lib"
    if [ -f "$getoptions_lib_path" ]; then
        . "$getoptions_lib_path"
    fi

    # Source bin/sb but prevent it from executing main logic
    # We do this by defining the functions we need to test directly
    # by sourcing the file and breaking before main execution
    eval "$(sed -n '/^check_sync_dependencies()/,/^}/p' "$SB_SCRIPT")"
    eval "$(sed -n '/^resolve_sandbox_env_tokens()/,/^}/p' "$SB_SCRIPT")"
}

# Create a temporary directory for test fixtures
setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    source_sb_helpers
}

# Clean up temporary directory after each test
teardown() {
    if [ -d "$TEST_TEMP_DIR" ]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Helper: Create a test .env file with given key=value pairs
# Usage: create_test_env_file <path> <key1=value1> [key2=value2] ...
create_test_env_file() {
    local path="$1"
    shift
    > "$path"
    for kv in "$@"; do
        echo "$kv" >> "$path"
    done
}
