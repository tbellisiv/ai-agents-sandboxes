#!/bin/bash
# test_helper.bash - Shared helper functions for sb ls unit tests

# Resolve the absolute path to the project root (three levels up from this file)
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$TESTS_DIR/../../.." && pwd)"
SB_SCRIPT="$PROJECT_ROOT/bin/sb"

# SCRIPT_NAME is used by the functions sourced from bin/sb
SCRIPT_NAME="sb"

# Source the sandbox_ls function and its dependency from bin/sb
source_sb_helpers() {
    # Source the getoptions lib first (required by bin/sb)
    local lib_dir="$PROJECT_ROOT/lib"
    local getoptions_lib_path="$lib_dir/getoptions_lib"
    if [ -f "$getoptions_lib_path" ]; then
        . "$getoptions_lib_path"
    fi

    eval "$(sed -n '/^dir_search_tree_up_by_dirname()/,/^}/p' "$SB_SCRIPT")"
    eval "$(sed -n '/^sandbox_ls()/,/^}/p' "$SB_SCRIPT")"
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

# Helper: Create a sandbox directory with sb-sandbox.env
# Usage: create_test_sandbox <project_root> <sandbox_id> <template_id> <image>
create_test_sandbox() {
    local project_root="$1"
    local sandbox_id="$2"
    local template_id="$3"
    local image="$4"

    local sandbox_dir="$project_root/sandboxes/$sandbox_id"
    mkdir -p "$sandbox_dir"
    cat > "$sandbox_dir/sb-sandbox.env" << EOF
SB_SANDBOX_TEMPLATE_ID="$template_id"
SB_SANDBOX_IMAGE=$image
SB_SANDBOX_SHELL=/bin/bash
EOF
}

# Helper: Create a project directory with sb-project.env and sandboxes dir
# Usage: create_test_project <project_root>
create_test_project() {
    local project_root="$1"
    mkdir -p "$project_root/sandboxes"
    cat > "$project_root/sb-project.env" << EOF
SB_PROJECT_ID=test-project
EOF
}
