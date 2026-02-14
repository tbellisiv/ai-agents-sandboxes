# Update `sb ps` Subcommand - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Update `sb ps` to display status for all sandboxes (like `sb ls`) with Docker container runtime data, in multiple output formats (table, plain, json, yaml) via a new `-o`/`--output` option.

**Architecture:** The current `sandbox_ps()` in `bin/sb` (lines 869-899) operates on a single sandbox using `get_sandbox_cmd_conf()` and calls `docker compose ps` directly. We will: (1) add an `-o`/`--output` param to `parser_definition_ps()`, (2) fix the usage string bug ("compose" -> "ps"), (3) rewrite `sandbox_ps()` to iterate all sandboxes (like `sandbox_ls()` at lines 950-1082), collecting static data from `sb-sandbox.env` and runtime data from `docker compose ps`, then format output based on the selected format, (4) update the dispatcher to remove the single-sandbox argument. Unit tests use BATS with a mock `docker` command, following the existing test patterns in `tests/sb-ls/unit/`.

**Tech Stack:** Bash, BATS (testing), mock `docker` script for test isolation

**Output formats:**
- `table` (default): 6 columns — `SANDBOX ID`, `STATUS`, `CREATED`, `CONTAINER_NAME`, `SERVICE`, `IMAGE` — with separator and data rows (4-space column gap, uppercase headers, matching `sb ls` style)
- `plain`: `<sandbox-id> [template=<template-id>] [image=<image>]`
- `json`: JSON array of objects with all 7 fields (`sandbox_id`, `template_id`, `image`, `status`, `created`, `container_name`, `service`)
- `yaml`: YAML list of mappings with all 7 fields

**Docker compose data:** `STATUS`, `CREATED`, `CONTAINER_NAME`, `SERVICE` are populated from `docker compose -f <file> ps -a --format '{{.Name}}|{{.Status}}|{{.RunningFor}}|{{.Service}}' <service>`. Sandboxes without containers show empty values for these fields.

---

## Plan Summary: 9 Tasks

| Task | Description | Files |
|------|-------------|-------|
| 1 | Create test infrastructure (helpers, mock docker, runner) | Create: `tests/sb-ps/unit/test_helper.bash`, `tests/sb-ps/unit/run-tests.sh` |
| 2 | Write BATS tests for table format | Create: `tests/sb-ps/unit/sandbox_ps.bats` |
| 3 | Write BATS tests for plain, JSON, YAML, errors, edge cases | Modify: `tests/sb-ps/unit/sandbox_ps.bats` |
| 4 | Run tests to verify they fail | Run: `tests/sb-ps/unit/run-tests.sh` |
| 5 | Update `parser_definition_ps()` | Modify: `bin/sb:158-164` |
| 6 | Rewrite `sandbox_ps()` function | Modify: `bin/sb:869-899` |
| 7 | Update dispatcher to remove sandbox argument | Modify: `bin/sb:2365-2370` |
| 8 | Run tests to verify they pass | Run: `tests/sb-ps/unit/run-tests.sh` |
| 9 | Manual verification and commit | All changed files |

**Totals:** 1 modified file (`bin/sb`), 2 new files (test infrastructure)

---

## Task 1: Create Test Infrastructure

Create BATS test helper with mock `docker` command and test runner script. The mock docker intercepts `docker compose ps` calls and returns content from a `.mock-ps-output` file placed in the sandbox directory by test helpers.

### Step 1: Create test helper

**Create:** `tests/sb-ps/unit/test_helper.bash`

```bash
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
```

### Step 2: Create test runner

**Create:** `tests/sb-ps/unit/run-tests.sh`

```bash
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
```

### Step 3: Make runner executable

Run: `chmod +x tests/sb-ps/unit/run-tests.sh`

### Step 4: Commit test infrastructure

```bash
git add tests/sb-ps/unit/test_helper.bash tests/sb-ps/unit/run-tests.sh
git commit -m "test: add sb ps test infrastructure with mock docker"
```

---

## Task 2: Write BATS Tests for Table Format

**Create:** `tests/sb-ps/unit/sandbox_ps.bats`

### Step 1: Write table format tests

```bash
#!/usr/bin/env bats
# sandbox_ps.bats - Unit tests for sandbox_ps() output formats

load test_helper

# =============================================================================
# TABLE FORMAT TESTS (default)
# =============================================================================

@test "T1: table: displays header with uppercase column names" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"
    set_mock_ps_output "$TEST_TEMP_DIR/project" "sandbox1" "test-proj-sandbox1" "Up 19 hours (healthy)" "19 hours ago" "sandbox"

    project_path="$TEST_TEMP_DIR/project"
    output_format="table"
    run sandbox_ps
    [ "$status" -eq 0 ]

    header=$(echo "$output" | head -n 1)
    [[ "$header" =~ ^SANDBOX\ ID ]]
    [[ "$header" =~ STATUS ]]
    [[ "$header" =~ CREATED ]]
    [[ "$header" =~ CONTAINER_NAME ]]
    [[ "$header" =~ SERVICE ]]
    [[ "$header" =~ IMAGE$ ]]
}

@test "T2: table: displays separator with dashes as second line" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"
    set_mock_ps_output "$TEST_TEMP_DIR/project" "sandbox1" "test-proj-sandbox1" "Up 19 hours (healthy)" "19 hours ago" "sandbox"

    project_path="$TEST_TEMP_DIR/project"
    output_format="table"
    run sandbox_ps
    [ "$status" -eq 0 ]

    separator=$(echo "$output" | sed -n '2p')
    # Separator should contain only dashes and spaces
    [[ "$separator" =~ ^[-\ ]+$ ]]
    # Should have dashes for each column
    [[ "$separator" =~ ---------- ]]
    [[ "$separator" =~ ------ ]]
    [[ "$separator" =~ ------- ]]
    [[ "$separator" =~ -------------- ]]
    [[ "$separator" =~ -----$ ]]
}

@test "T3: table: displays single sandbox row with correct values" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "default" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"
    set_mock_ps_output "$TEST_TEMP_DIR/project" "default" "test-proj-default" "Up 19 hours (healthy)" "19 hours ago" "sandbox"

    project_path="$TEST_TEMP_DIR/project"
    output_format="table"
    run sandbox_ps
    [ "$status" -eq 0 ]

    data_row=$(echo "$output" | sed -n '3p')
    [[ "$data_row" =~ ^default ]]
    [[ "$data_row" =~ Up\ 19\ hours\ \(healthy\) ]]
    [[ "$data_row" =~ 19\ hours\ ago ]]
    [[ "$data_row" =~ test-proj-default ]]
    [[ "$data_row" =~ sandbox ]]
    [[ "$data_row" =~ sb-ubuntu-noble:latest$ ]]
}

@test "T4: table: displays multiple sandboxes with aligned columns" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "default" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"
    create_test_sandbox "$TEST_TEMP_DIR/project" "dev-main" "sb-ubuntu-noble-fw" "sb-ubuntu-noble-fw:latest"
    set_mock_ps_output "$TEST_TEMP_DIR/project" "default" "test-proj-default" "Up 19 hours (healthy)" "19 hours ago" "sandbox"
    set_mock_ps_output "$TEST_TEMP_DIR/project" "dev-main" "test-proj-dev-main" "Paused" "26 hours ago" "sandbox"

    project_path="$TEST_TEMP_DIR/project"
    output_format="table"
    run sandbox_ps
    [ "$status" -eq 0 ]

    # Should have header + separator + 2 data rows = 4 lines
    line_count=$(echo "$output" | wc -l)
    [ "$line_count" -eq 4 ]

    [[ "$output" =~ default ]]
    [[ "$output" =~ Up\ 19\ hours ]]
    [[ "$output" =~ dev-main ]]
    [[ "$output" =~ Paused ]]
}

@test "T5: table: displays header and separator when no sandboxes exist" {
    create_test_project "$TEST_TEMP_DIR/project"

    project_path="$TEST_TEMP_DIR/project"
    output_format="table"
    run sandbox_ps
    [ "$status" -eq 0 ]

    line_count=$(echo "$output" | wc -l)
    [ "$line_count" -eq 2 ]

    header=$(echo "$output" | head -n 1)
    [ "$header" = "SANDBOX ID    STATUS    CREATED    CONTAINER_NAME    SERVICE    IMAGE" ]

    separator=$(echo "$output" | sed -n '2p')
    [ "$separator" = "----------    ------    -------    --------------    -------    -----" ]
}

@test "T6: table: is the default format when output_format is not set" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"
    set_mock_ps_output "$TEST_TEMP_DIR/project" "sandbox1" "test-proj-sandbox1" "Up 5 minutes" "5 minutes ago" "sandbox"

    project_path="$TEST_TEMP_DIR/project"
    output_format=
    run sandbox_ps
    [ "$status" -eq 0 ]

    header=$(echo "$output" | head -n 1)
    [[ "$header" =~ ^SANDBOX\ ID ]]
}

@test "T7: table: shows sandbox with no container (empty runtime fields)" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "no-container" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"
    # No set_mock_ps_output — simulates sandbox with no container

    project_path="$TEST_TEMP_DIR/project"
    output_format="table"
    run sandbox_ps
    [ "$status" -eq 0 ]

    # Should still show the sandbox row with the sandbox ID and image
    [[ "$output" =~ no-container ]]
    [[ "$output" =~ sb-ubuntu-noble:latest ]]
}
```

### Step 2: Commit tests

```bash
git add tests/sb-ps/unit/sandbox_ps.bats
git commit -m "test: add sb ps table format tests"
```

---

## Task 3: Write BATS Tests for Plain, JSON, YAML, Errors, Edge Cases

Append remaining tests to `tests/sb-ps/unit/sandbox_ps.bats`.

### Step 1: Add plain, JSON, YAML, error, and edge case tests

**Modify:** `tests/sb-ps/unit/sandbox_ps.bats` — append after the table tests:

```bash
# =============================================================================
# PLAIN FORMAT TESTS
# =============================================================================

@test "T8: plain: displays single sandbox in correct format" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"
    set_mock_ps_output "$TEST_TEMP_DIR/project" "sandbox1" "test-proj-sandbox1" "Up 5 minutes" "5 minutes ago" "sandbox"

    project_path="$TEST_TEMP_DIR/project"
    output_format="plain"
    run sandbox_ps
    [ "$status" -eq 0 ]
    [[ "$output" =~ "sandbox1 [template=sb-ubuntu-noble] [image=sb-ubuntu-noble:latest]" ]]
}

@test "T9: plain: displays multiple sandboxes" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox2" "sb-ubuntu-noble-fw" "sb-ubuntu-noble-fw:latest"
    set_mock_ps_output "$TEST_TEMP_DIR/project" "sandbox1" "proj-sandbox1" "Up 5 minutes" "5 minutes ago" "sandbox"
    set_mock_ps_output "$TEST_TEMP_DIR/project" "sandbox2" "proj-sandbox2" "Paused" "10 minutes ago" "sandbox"

    project_path="$TEST_TEMP_DIR/project"
    output_format="plain"
    run sandbox_ps
    [ "$status" -eq 0 ]

    line_count=$(echo "$output" | wc -l)
    [ "$line_count" -eq 2 ]

    [[ "$output" =~ "sandbox1 [template=sb-ubuntu-noble] [image=sb-ubuntu-noble:latest]" ]]
    [[ "$output" =~ "sandbox2 [template=sb-ubuntu-noble-fw] [image=sb-ubuntu-noble-fw:latest]" ]]
}

@test "T10: plain: produces no output when no sandboxes exist" {
    create_test_project "$TEST_TEMP_DIR/project"

    project_path="$TEST_TEMP_DIR/project"
    output_format="plain"
    run sandbox_ps
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

# =============================================================================
# JSON FORMAT TESTS
# =============================================================================

@test "T11: json: displays single sandbox as JSON array with all fields" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"
    set_mock_ps_output "$TEST_TEMP_DIR/project" "sandbox1" "test-proj-sandbox1" "Up 19 hours (healthy)" "19 hours ago" "sandbox"

    project_path="$TEST_TEMP_DIR/project"
    output_format="json"
    run sandbox_ps
    [ "$status" -eq 0 ]

    [[ "$output" =~ "[" ]]
    [[ "$output" =~ "\"sandbox_id\": \"sandbox1\"" ]]
    [[ "$output" =~ "\"template_id\": \"sb-ubuntu-noble\"" ]]
    [[ "$output" =~ "\"image\": \"sb-ubuntu-noble:latest\"" ]]
    [[ "$output" =~ "\"status\": \"Up 19 hours (healthy)\"" ]]
    [[ "$output" =~ "\"created\": \"19 hours ago\"" ]]
    [[ "$output" =~ "\"container_name\": \"test-proj-sandbox1\"" ]]
    [[ "$output" =~ "\"service\": \"sandbox\"" ]]
    [[ "$output" =~ "]" ]]
}

@test "T12: json: displays multiple sandboxes as JSON array" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox2" "sb-ubuntu-noble-fw" "sb-ubuntu-noble-fw:latest"
    set_mock_ps_output "$TEST_TEMP_DIR/project" "sandbox1" "proj-sandbox1" "Up 5 minutes" "5 minutes ago" "sandbox"
    set_mock_ps_output "$TEST_TEMP_DIR/project" "sandbox2" "proj-sandbox2" "Paused" "10 minutes ago" "sandbox"

    project_path="$TEST_TEMP_DIR/project"
    output_format="json"
    run sandbox_ps
    [ "$status" -eq 0 ]

    [[ "$output" =~ "\"sandbox_id\": \"sandbox1\"" ]]
    [[ "$output" =~ "\"sandbox_id\": \"sandbox2\"" ]]
}

@test "T13: json: displays empty array when no sandboxes exist" {
    create_test_project "$TEST_TEMP_DIR/project"

    project_path="$TEST_TEMP_DIR/project"
    output_format="json"
    run sandbox_ps
    [ "$status" -eq 0 ]
    [ "$output" = "[]" ]
}

@test "T14: json: includes empty strings for sandbox with no container" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"
    # No set_mock_ps_output — no container

    project_path="$TEST_TEMP_DIR/project"
    output_format="json"
    run sandbox_ps
    [ "$status" -eq 0 ]

    [[ "$output" =~ "\"sandbox_id\": \"sandbox1\"" ]]
    [[ "$output" =~ "\"status\": \"\"" ]]
    [[ "$output" =~ "\"created\": \"\"" ]]
    [[ "$output" =~ "\"container_name\": \"\"" ]]
    [[ "$output" =~ "\"service\": \"\"" ]]
}

# =============================================================================
# YAML FORMAT TESTS
# =============================================================================

@test "T15: yaml: displays single sandbox as YAML list item with all fields" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"
    set_mock_ps_output "$TEST_TEMP_DIR/project" "sandbox1" "test-proj-sandbox1" "Up 19 hours (healthy)" "19 hours ago" "sandbox"

    project_path="$TEST_TEMP_DIR/project"
    output_format="yaml"
    run sandbox_ps
    [ "$status" -eq 0 ]

    [[ "$output" =~ "- sandbox_id: sandbox1" ]]
    [[ "$output" =~ "  template_id: sb-ubuntu-noble" ]]
    [[ "$output" =~ "  image: sb-ubuntu-noble:latest" ]]
    [[ "$output" =~ "  status: Up 19 hours (healthy)" ]]
    [[ "$output" =~ "  created: 19 hours ago" ]]
    [[ "$output" =~ "  container_name: test-proj-sandbox1" ]]
    [[ "$output" =~ "  service: sandbox" ]]
}

@test "T16: yaml: displays multiple sandboxes as YAML list" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox2" "sb-ubuntu-noble-fw" "sb-ubuntu-noble-fw:latest"
    set_mock_ps_output "$TEST_TEMP_DIR/project" "sandbox1" "proj-sandbox1" "Up 5 minutes" "5 minutes ago" "sandbox"
    set_mock_ps_output "$TEST_TEMP_DIR/project" "sandbox2" "proj-sandbox2" "Paused" "10 minutes ago" "sandbox"

    project_path="$TEST_TEMP_DIR/project"
    output_format="yaml"
    run sandbox_ps
    [ "$status" -eq 0 ]

    [[ "$output" =~ "- sandbox_id: sandbox1" ]]
    [[ "$output" =~ "- sandbox_id: sandbox2" ]]
}

@test "T17: yaml: displays empty list when no sandboxes exist" {
    create_test_project "$TEST_TEMP_DIR/project"

    project_path="$TEST_TEMP_DIR/project"
    output_format="yaml"
    run sandbox_ps
    [ "$status" -eq 0 ]
    [ "$output" = "[]" ]
}

# =============================================================================
# ERROR HANDLING TESTS
# =============================================================================

@test "T18: fails when project path does not exist" {
    project_path="$TEST_TEMP_DIR/nonexistent"
    run sandbox_ps
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error" ]]
}

@test "T19: fails when sandboxes directory does not exist" {
    mkdir -p "$TEST_TEMP_DIR/project"
    cat > "$TEST_TEMP_DIR/project/sb-project.env" << EOF
SB_PROJECT_ID=test-project
EOF

    project_path="$TEST_TEMP_DIR/project"
    run sandbox_ps
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error" ]]
}

@test "T20: fails with unknown output format" {
    create_test_project "$TEST_TEMP_DIR/project"

    project_path="$TEST_TEMP_DIR/project"
    output_format="invalid"
    run sandbox_ps
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown output format" ]]
}

# =============================================================================
# EDGE CASE TESTS
# =============================================================================

@test "T21: handles sandbox with quoted values in sb-sandbox.env" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "my-sandbox" "sb-ubuntu-noble-fw-opensnitch" "sb-ubuntu-noble-fw-opensnitch:latest"
    set_mock_ps_output "$TEST_TEMP_DIR/project" "my-sandbox" "proj-my-sandbox" "Up 2 minutes" "2 minutes ago" "sandbox"

    project_path="$TEST_TEMP_DIR/project"
    output_format="table"
    run sandbox_ps
    [ "$status" -eq 0 ]

    [[ "$output" =~ my-sandbox ]]
    [[ "$output" =~ sb-ubuntu-noble-fw-opensnitch:latest ]]
    [[ "$output" =~ proj-my-sandbox ]]
}

@test "T22: handles sandbox missing sb-sandbox.env gracefully" {
    create_test_project "$TEST_TEMP_DIR/project"
    # Create sandbox dir with compose files but no sb-sandbox.env
    local sandbox_dir="$TEST_TEMP_DIR/project/sandboxes/broken-sandbox"
    mkdir -p "$sandbox_dir"
    cat > "$sandbox_dir/sb-compose.env" << EOF
SB_COMPOSE_SERVICE=sandbox
EOF
    cat > "$sandbox_dir/docker-compose.yml" << EOF
services:
  sandbox:
    image: test:latest
EOF

    project_path="$TEST_TEMP_DIR/project"
    output_format="table"
    run sandbox_ps
    [ "$status" -eq 0 ]

    header=$(echo "$output" | head -n 1)
    [[ "$header" =~ ^SANDBOX\ ID ]]
    [[ "$output" =~ broken-sandbox ]]
}

@test "T23: handles sandbox missing docker-compose.yml (empty runtime fields)" {
    create_test_project "$TEST_TEMP_DIR/project"
    # Create sandbox with only sb-sandbox.env (no compose files)
    local sandbox_dir="$TEST_TEMP_DIR/project/sandboxes/no-compose"
    mkdir -p "$sandbox_dir"
    cat > "$sandbox_dir/sb-sandbox.env" << EOF
SB_SANDBOX_TEMPLATE_ID="sb-ubuntu-noble"
SB_SANDBOX_IMAGE=sb-ubuntu-noble:latest
SB_SANDBOX_SHELL=/bin/bash
EOF

    project_path="$TEST_TEMP_DIR/project"
    output_format="json"
    run sandbox_ps
    [ "$status" -eq 0 ]

    [[ "$output" =~ "\"sandbox_id\": \"no-compose\"" ]]
    [[ "$output" =~ "\"template_id\": \"sb-ubuntu-noble\"" ]]
    [[ "$output" =~ "\"status\": \"\"" ]]
    [[ "$output" =~ "\"container_name\": \"\"" ]]
}
```

### Step 2: Commit tests

```bash
git add tests/sb-ps/unit/sandbox_ps.bats
git commit -m "test: add sb ps tests for all output formats and edge cases"
```

---

## Task 4: Run Tests to Verify They Fail

### Step 1: Run all tests

Run: `./tests/sb-ps/unit/run-tests.sh`

Expected: All 23 tests FAIL because `sandbox_ps()` has not been updated yet. The `sed` extraction will get the old function which has a different signature and behavior.

---

## Task 5: Update `parser_definition_ps()`

**Modify:** `bin/sb:158-164`

### Step 1: Fix usage string and add output format option

Replace the current `parser_definition_ps()`:

```bash
parser_definition_ps() {
  setup   REST error:error_init help:usage abbr:true -- "Usage: $SCRIPT_NAME compose [<sandbox>] [<options>]"
  msg -- '' 'Displays sandbox status'
  msg -- 'Options:'
  param   project_path  -p    --project-path                                                                                    -- "The path to the project directory (the ".sb" directory). If not specified, $SCRIPT_NAME will attempt to find the path based on the current directory"
  disp    :usage        -h    --help
}
```

With:

```bash
parser_definition_ps() {
  setup   REST error:error_init help:usage abbr:true -- "Usage: $SCRIPT_NAME ps [<options>]"
  msg -- '' 'Displays status for all sandboxes in the project'
  msg -- 'Options:'
  param   output_format -o    --output                                                                                          -- "Output format: table (default), plain, json, yaml"
  param   project_path  -p    --project-path                                                                                    -- "The path to the project directory (the \".sb\" directory). If not specified, $SCRIPT_NAME will attempt to find the path based on the current directory"
  disp    :usage        -h    --help
}
```

**Changes:**
1. Fixed usage string: `"compose [<sandbox>] [<options>]"` → `"ps [<options>]"` (fixes bug and removes sandbox arg)
2. Updated description: `'Displays sandbox status'` → `'Displays status for all sandboxes in the project'`
3. Added `output_format` param with `-o`/`--output` option (same as `parser_definition_ls()` at line 187)
4. Fixed quoting on `project_path` help text: uses `\"` for inner quotes (matches `parser_definition_ls()`)

### Step 2: Commit

```bash
git add bin/sb
git commit -m "feat: update sb ps parser - fix usage string, add -o/--output option"
```

---

## Task 6: Rewrite `sandbox_ps()` Function

**Modify:** `bin/sb:869-899`

### Step 1: Replace the current `sandbox_ps()` function

Replace the current function (lines 869-899):

```bash
sandbox_ps() {

  #get the sandbox config
  cmd_conf=$(get_sandbox_cmd_conf)
  if [ $? -ne 0 ]; then
    if [ -n "$cmd_conf" ]; then
      echo "$cmd_conf"
    fi
    exit 1
  fi
  eval "$cmd_conf"

  echo ""
  echo "$SCRIPT_NAME: Sandbox '$__sandbox_id' at '$__sandbox_root'"
  echo ""
  state=$(docker compose -f $__compose_file ps $__compose_service --format "State: {{.State}}")
  if [ $? -ne 0 ]; then
    echo "$SCRIPT_NAME: Error- docker compose ps failed"
    exit 1
  fi

  if [ -z "$state" ]; then
    echo "$SCRIPT_NAME: State: not-running"
  else
    echo "$SCRIPT_NAME: Sandbox '$__sandbox_id' status:"
    echo ""
    docker compose -f $__compose_file ps $__compose_service
    echo ""
  fi

}
```

With this new implementation:

```bash
sandbox_ps() {

  local ps_output_format="${output_format:-table}"

  # get the path to the project
  if [ -z "$project_path" ]; then
    #search for project root
    project_path=$(dir_search_tree_up_by_dirname ".sb")
    if [ -z "$project_path" ]; then
      echo "$SCRIPT_NAME: Error: Unable to find sandbox project root directory. 'cd' into the directory tree containing the sandbox project or run 'sb-project init' to create a project"
      exit 1
    fi
  else
    if [ ! -d "$project_path" ]; then
      echo "$SCRIPT_NAME: Error: Sandbox project root directory '$project_path' does not exist"
      exit 1
    fi
  fi

  # get the path to sb-project.env
  project_path_abs=$(readlink -f "$project_path")

  project_env_path=$project_path/sb-project.env
  if [ ! -f "$project_env_path" ]; then
    echo "$SCRIPT_NAME: Error: Sandbox project configuration file '$project_path_abs' does not exist"
    exit 1
  fi

  sandboxes_root_path=$project_path_abs/sandboxes
  if [ ! -d "$sandboxes_root_path" ]; then
    echo "$SCRIPT_NAME: Error: Sandbox root directory '$sandboxes_root_path' does not exist"
    exit 1
  fi

  # Collect sandbox data
  local sandbox_ids=()
  local template_ids=()
  local images=()
  local statuses=()
  local createds=()
  local container_names=()
  local services_arr=()

  for sandbox_dir in "$sandboxes_root_path"/*/; do
    # Skip if no directories found (glob returned the literal pattern)
    [ -d "$sandbox_dir" ] || continue

    local sandbox_id
    sandbox_id=$(basename "$sandbox_dir")

    local sandbox_env_file="$sandbox_dir/sb-sandbox.env"
    local template_id=""
    local image=""

    if [ -f "$sandbox_env_file" ]; then
      # Read values using grep+sed to avoid polluting the current shell
      template_id=$(grep '^SB_SANDBOX_TEMPLATE_ID=' "$sandbox_env_file" | head -1 | sed 's/^SB_SANDBOX_TEMPLATE_ID=//' | sed 's/^"//;s/"$//')
      image=$(grep '^SB_SANDBOX_IMAGE=' "$sandbox_env_file" | head -1 | sed 's/^SB_SANDBOX_IMAGE=//' | sed 's/^"//;s/"$//')
    fi

    # Get docker compose ps data
    local status="" created="" container_name="" service=""
    local compose_file="$sandbox_dir/docker-compose.yml"
    local compose_env_file="$sandbox_dir/sb-compose.env"

    if [ -f "$compose_file" ] && [ -f "$compose_env_file" ]; then
      local compose_service
      compose_service=$(grep '^SB_COMPOSE_SERVICE=' "$compose_env_file" | head -1 | sed 's/^SB_COMPOSE_SERVICE=//' | sed 's/^"//;s/"$//')

      if [ -n "$compose_service" ]; then
        local ps_line
        ps_line=$(docker compose -f "$compose_file" ps -a --format '{{.Name}}|{{.Status}}|{{.RunningFor}}|{{.Service}}' "$compose_service" 2>/dev/null)

        if [ -n "$ps_line" ]; then
          IFS='|' read -r container_name status created service <<< "$ps_line"
        fi
      fi
    fi

    sandbox_ids+=("$sandbox_id")
    template_ids+=("$template_id")
    images+=("$image")
    statuses+=("$status")
    createds+=("$created")
    container_names+=("$container_name")
    services_arr+=("$service")
  done

  # Format output
  case "$ps_output_format" in
    table)
      # Column headers
      local h1="SANDBOX ID" h2="STATUS" h3="CREATED" h4="CONTAINER_NAME" h5="SERVICE" h6="IMAGE"

      # Compute max width for each column (except last)
      local w1=${#h1} w2=${#h2} w3=${#h3} w4=${#h4} w5=${#h5}
      for i in "${!sandbox_ids[@]}"; do
        [ ${#sandbox_ids[$i]} -gt $w1 ] && w1=${#sandbox_ids[$i]}
        [ ${#statuses[$i]} -gt $w2 ] && w2=${#statuses[$i]}
        [ ${#createds[$i]} -gt $w3 ] && w3=${#createds[$i]}
        [ ${#container_names[$i]} -gt $w4 ] && w4=${#container_names[$i]}
        [ ${#services_arr[$i]} -gt $w5 ] && w5=${#services_arr[$i]}
      done

      # Column widths with 4-space gap (last column has no gap)
      local cw1=$((w1 + 4))
      local cw2=$((w2 + 4))
      local cw3=$((w3 + 4))
      local cw4=$((w4 + 4))
      local cw5=$((w5 + 4))

      # Print header
      printf "%-${cw1}s%-${cw2}s%-${cw3}s%-${cw4}s%-${cw5}s%s\n" "$h1" "$h2" "$h3" "$h4" "$h5" "$h6"

      # Print separator (dashes matching header text length, padded to column width)
      local s1=$(printf '%*s' ${#h1} '' | tr ' ' '-')
      local s2=$(printf '%*s' ${#h2} '' | tr ' ' '-')
      local s3=$(printf '%*s' ${#h3} '' | tr ' ' '-')
      local s4=$(printf '%*s' ${#h4} '' | tr ' ' '-')
      local s5=$(printf '%*s' ${#h5} '' | tr ' ' '-')
      local s6=$(printf '%*s' ${#h6} '' | tr ' ' '-')
      printf "%-${cw1}s%-${cw2}s%-${cw3}s%-${cw4}s%-${cw5}s%s\n" "$s1" "$s2" "$s3" "$s4" "$s5" "$s6"

      # Print data rows
      for i in "${!sandbox_ids[@]}"; do
        printf "%-${cw1}s%-${cw2}s%-${cw3}s%-${cw4}s%-${cw5}s%s\n" "${sandbox_ids[$i]}" "${statuses[$i]}" "${createds[$i]}" "${container_names[$i]}" "${services_arr[$i]}" "${images[$i]}"
      done
      ;;
    plain)
      for i in "${!sandbox_ids[@]}"; do
        echo "${sandbox_ids[$i]} [template=${template_ids[$i]}] [image=${images[$i]}]"
      done
      ;;
    json)
      local count=${#sandbox_ids[@]}
      if [ "$count" -eq 0 ]; then
        echo "[]"
      else
        echo "["
        for i in "${!sandbox_ids[@]}"; do
          local comma=","
          if [ $((i + 1)) -eq "$count" ]; then comma=""; fi
          echo "  {"
          echo "    \"sandbox_id\": \"${sandbox_ids[$i]}\","
          echo "    \"template_id\": \"${template_ids[$i]}\","
          echo "    \"image\": \"${images[$i]}\","
          echo "    \"status\": \"${statuses[$i]}\","
          echo "    \"created\": \"${createds[$i]}\","
          echo "    \"container_name\": \"${container_names[$i]}\","
          echo "    \"service\": \"${services_arr[$i]}\""
          echo "  }${comma}"
        done
        echo "]"
      fi
      ;;
    yaml)
      if [ ${#sandbox_ids[@]} -eq 0 ]; then
        echo "[]"
      else
        for i in "${!sandbox_ids[@]}"; do
          echo "- sandbox_id: ${sandbox_ids[$i]}"
          echo "  template_id: ${template_ids[$i]}"
          echo "  image: ${images[$i]}"
          echo "  status: ${statuses[$i]}"
          echo "  created: ${createds[$i]}"
          echo "  container_name: ${container_names[$i]}"
          echo "  service: ${services_arr[$i]}"
        done
      fi
      ;;
    *)
      echo "$SCRIPT_NAME: Error: Unknown output format '$ps_output_format'. Valid formats: table, plain, json, yaml"
      exit 1
      ;;
  esac

}
```

**Key design decisions:**
- Uses the same project/sandbox discovery pattern as `sandbox_ls()` (lines 950-982)
- Reads `sb-sandbox.env` and `sb-compose.env` using `grep+sed` (not `source`) for safety
- Calls `docker compose ps -a --format '{{.Name}}|{{.Status}}|{{.RunningFor}}|{{.Service}}'` with pipe delimiter
- Gracefully handles missing `docker-compose.yml`, `sb-compose.env`, or no container (empty strings)
- Table format: 6 columns with 4-space gap, uppercase headers, matching `sb ls` style
- Plain format matches `sb ls` exactly: `<id> [template=<tid>] [image=<img>]`
- JSON/YAML include all 7 fields (sandbox_id, template_id, image, status, created, container_name, service)

### Step 2: Commit

```bash
git add bin/sb
git commit -m "feat: rewrite sandbox_ps to show all sandboxes with docker compose status"
```

---

## Task 7: Update Dispatcher to Remove Sandbox Argument

**Modify:** `bin/sb:2365-2370`

### Step 1: Update the `ps)` case in the dispatcher

Replace:

```bash
    ps)
        cmd_parser="$(getoptions parser_definition_ps)"
        eval "$cmd_parser"
        sandbox=$1
        sandbox_ps $sandbox
        ;;
```

With:

```bash
    ps)
        cmd_parser="$(getoptions parser_definition_ps)"
        eval "$cmd_parser"
        sandbox_ps
        ;;
```

**Changes:** Removed `sandbox=$1` and `$sandbox` argument — `sandbox_ps` now operates on all sandboxes (like `sandbox_ls` at line 2386).

### Step 2: Commit

```bash
git add bin/sb
git commit -m "feat: update sb ps dispatcher to match sb ls (no sandbox argument)"
```

---

## Task 8: Run Tests to Verify They Pass

### Step 1: Run all tests

Run: `./tests/sb-ps/unit/run-tests.sh`

Expected: All 23 tests PASS.

### Step 2: Run sb ls tests to verify no regression

Run: `./tests/sb-ls/unit/run-tests.sh`

Expected: All 20 tests PASS (no changes to `sandbox_ls`).

### Step 3: Fix any failures

If any tests fail, debug and fix. Common issues to check:
- Whitespace/alignment mismatches in table format assertions
- Missing fields in JSON/YAML output
- Mock docker PATH not taking precedence

---

## Task 9: Manual Verification and Commit

### Step 1: Verify `sb ps --help` output

Run: `sb ps --help`

Expected output should show:
```
Usage: sb ps [<options>]

Displays status for all sandboxes in the project
Options:
  -o, --output OUTPUT_FORMAT  Output format: table (default), plain, json, yaml
  -p, --project-path PROJECT_PATH
                              The path to the project directory...
  -h, --help
```

### Step 2: Verify `sb ps` with live sandboxes (if available)

If a sandbox project with running containers is available:

```bash
sb ps                     # Table format (default)
sb ps -o plain            # Plain format
sb ps -o json             # JSON format
sb ps -o yaml             # YAML format
```

### Step 3: Final commit (if any fixes were needed)

```bash
git add -A
git commit -m "feat: update sb ps to show all sandboxes with multi-format output"
```
