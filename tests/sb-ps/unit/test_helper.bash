#!/bin/bash
# test_helper.bash - Shared helper functions for sb ps unit tests

# Resolve the absolute path to the project root (three levels up from this file)
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$TESTS_DIR/../../.." && pwd)"
SB_SCRIPT="$PROJECT_ROOT/bin/sb"

# SCRIPT_NAME is used by the functions sourced from bin/sb
SCRIPT_NAME="sb"

# Source the sandbox_ps function and its dependency from bin/sb
source_sb_helpers() {
    # Source the getoptions lib first (required by bin/sb)
    local lib_dir="$PROJECT_ROOT/lib"
    local getoptions_lib_path="$lib_dir/getoptions_lib"
    if [ -f "$getoptions_lib_path" ]; then
        . "$getoptions_lib_path"
    fi

    eval "$(sed -n '/^dir_search_tree_up_by_dirname()/,/^}/p' "$SB_SCRIPT")"
    eval "$(sed -n '/^sandbox_ps()/,/^}/p' "$SB_SCRIPT")"
}

# Create a temporary directory for test fixtures and set up mock docker
setup() {
    TEST_TEMP_DIR="$(mktemp -d)"

    # Create mock docker command that returns content from .mock-ps-output
    MOCK_BIN_DIR="$TEST_TEMP_DIR/mock-bin"
    mkdir -p "$MOCK_BIN_DIR"
    cat > "$MOCK_BIN_DIR/docker" << 'MOCK_EOF'
#!/bin/bash
# Mock docker command for sb ps tests
# Intercepts "docker compose -f <file> ps ..." and returns .mock-ps-output content
compose_file=""
is_compose=false
is_ps=false
args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
    case "${args[$i]}" in
        compose) is_compose=true ;;
        -f) compose_file="${args[$((i+1))]}"; ((i++)) ;;
        ps) is_ps=true ;;
    esac
done
if $is_compose && $is_ps && [ -n "$compose_file" ]; then
    mock_file="$(dirname "$compose_file")/.mock-ps-output"
    if [ -f "$mock_file" ]; then
        cat "$mock_file"
    fi
fi
exit 0
MOCK_EOF
    chmod +x "$MOCK_BIN_DIR/docker"
    export PATH="$MOCK_BIN_DIR:$PATH"

    source_sb_helpers
}

# Clean up temporary directory after each test
teardown() {
    if [ -d "$TEST_TEMP_DIR" ]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
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

# Helper: Create a sandbox directory with sb-sandbox.env, sb-compose.env, and docker-compose.yml
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
    cat > "$sandbox_dir/sb-compose.env" << EOF
SB_COMPOSE_SERVICE=sandbox
EOF
    cat > "$sandbox_dir/docker-compose.yml" << EOF
services:
  sandbox:
    image: $image
EOF
}

# Helper: Set mock docker compose ps output for a sandbox
# Usage: set_mock_ps_output <project_root> <sandbox_id> <name> <status> <running_for> <service>
set_mock_ps_output() {
    local project_root="$1"
    local sandbox_id="$2"
    local name="$3"
    local status="$4"
    local running_for="$5"
    local service="$6"

    echo "${name}|${status}|${running_for}|${service}" > "$project_root/sandboxes/$sandbox_id/.mock-ps-output"
}
