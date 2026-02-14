# Update `sb ls` Subcommand - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Update `sb ls` to display sandbox information in multiple output formats (table, plain, json, yaml) via a new `-o`/`--output` option, with table as the default.

**Architecture:** The existing `sandbox_ls()` function in `bin/sb` (lines 949-983) currently lists sandbox directory names using `find -printf '%f\n'`. We will: (1) add an `-o`/`--output` param to `parser_definition_ls()`, (2) rewrite `sandbox_ls()` to collect sandbox data from each sandbox's `sb-sandbox.env` into arrays, then format output based on the selected format. Unit tests will be added using BATS, following the existing test patterns in `tests/sync/unit/`.

**Tech Stack:** Bash, BATS (testing)

**Output formats:**
- `table` (default): `|Sandbox ID|Template ID|Image|` with separator and data rows
- `plain`: `<sandbox-id> [template=<template-id>] [image=<image>]`
- `json`: JSON array of objects with `sandbox_id`, `template_id`, `image` keys
- `yaml`: YAML list of mappings with `sandbox_id`, `template_id`, `image` keys

---

## Plan Summary: 6 Tasks

| Task | Description | Files |
|------|-------------|-------|
| 1 | Write BATS unit tests for all `sandbox_ls` output formats | Create: `tests/sb-ls/unit/test_helper.bash`, `tests/sb-ls/unit/run-tests.sh`, `tests/sb-ls/unit/sandbox_ls.bats` |
| 2 | Run tests to verify they fail | `tests/sb-ls/unit/run-tests.sh` |
| 3 | Add `-o`/`--output` option to `parser_definition_ls()` | Modify: `bin/sb:183-189` |
| 4 | Update `sandbox_ls()` to support all four output formats | Modify: `bin/sb:949-983` |
| 5 | Run tests to verify they pass | `tests/sb-ls/unit/run-tests.sh` |
| 6 | Manual verification and commit | `bin/sb`, `tests/sb-ls/unit/*` |

**Totals:** 1 modified file (`bin/sb`), 3 new files (test infrastructure)

---

## Task 1: Write BATS Unit Tests for All `sandbox_ls` Output Formats

Create BATS tests that verify all four output formats. The tests create a fake `.sb/sandboxes/` directory structure with `sb-sandbox.env` files and validate the output.

### Step 1: Create test helper

**Create:** `tests/sb-ls/unit/test_helper.bash`

```bash
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
```

### Step 2: Create test runner

**Create:** `tests/sb-ls/unit/run-tests.sh`

```bash
#!/bin/bash
# run-tests.sh - Run sb ls unit tests using Bats
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
```

### Step 3: Create test file

**Create:** `tests/sb-ls/unit/sandbox_ls.bats`

```bash
#!/usr/bin/env bats
# sandbox_ls.bats - Unit tests for sandbox_ls() output formats

load test_helper

# =============================================================================
# TABLE FORMAT TESTS (default)
# =============================================================================

@test "T1: table: displays header with correct column names" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"

    project_path="$TEST_TEMP_DIR/project"
    output_format="table"
    run sandbox_ls
    [ "$status" -eq 0 ]

    header=$(echo "$output" | head -n 1)
    [ "$header" = "|Sandbox ID|Template ID|Image|" ]
}

@test "T2: table: displays separator as second line" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"

    project_path="$TEST_TEMP_DIR/project"
    output_format="table"
    run sandbox_ls
    [ "$status" -eq 0 ]

    separator=$(echo "$output" | sed -n '2p')
    [ "$separator" = "|----------|-----------|-----|" ]
}

@test "T3: table: displays single sandbox row with correct values" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"

    project_path="$TEST_TEMP_DIR/project"
    output_format="table"
    run sandbox_ls
    [ "$status" -eq 0 ]

    data_row=$(echo "$output" | sed -n '3p')
    [ "$data_row" = "|sandbox1|sb-ubuntu-noble|sb-ubuntu-noble:latest|" ]
}

@test "T4: table: displays multiple sandboxes" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox2" "sb-ubuntu-noble-fw" "sb-ubuntu-noble-fw:latest"

    project_path="$TEST_TEMP_DIR/project"
    output_format="table"
    run sandbox_ls
    [ "$status" -eq 0 ]

    line_count=$(echo "$output" | wc -l)
    [ "$line_count" -eq 4 ]

    [[ "$output" =~ "|sandbox1|sb-ubuntu-noble|sb-ubuntu-noble:latest|" ]]
    [[ "$output" =~ "|sandbox2|sb-ubuntu-noble-fw|sb-ubuntu-noble-fw:latest|" ]]
}

@test "T5: table: displays header and separator when no sandboxes exist" {
    create_test_project "$TEST_TEMP_DIR/project"

    project_path="$TEST_TEMP_DIR/project"
    output_format="table"
    run sandbox_ls
    [ "$status" -eq 0 ]

    line_count=$(echo "$output" | wc -l)
    [ "$line_count" -eq 2 ]

    header=$(echo "$output" | head -n 1)
    [ "$header" = "|Sandbox ID|Template ID|Image|" ]
}

@test "T6: table: is the default format when output_format is not set" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"

    project_path="$TEST_TEMP_DIR/project"
    output_format=
    run sandbox_ls
    [ "$status" -eq 0 ]

    header=$(echo "$output" | head -n 1)
    [ "$header" = "|Sandbox ID|Template ID|Image|" ]
}

# =============================================================================
# PLAIN FORMAT TESTS
# =============================================================================

@test "T7: plain: displays single sandbox in correct format" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"

    project_path="$TEST_TEMP_DIR/project"
    output_format="plain"
    run sandbox_ls
    [ "$status" -eq 0 ]
    [[ "$output" =~ "sandbox1 [template=sb-ubuntu-noble] [image=sb-ubuntu-noble:latest]" ]]
}

@test "T8: plain: displays multiple sandboxes" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox2" "sb-ubuntu-noble-fw" "sb-ubuntu-noble-fw:latest"

    project_path="$TEST_TEMP_DIR/project"
    output_format="plain"
    run sandbox_ls
    [ "$status" -eq 0 ]

    line_count=$(echo "$output" | wc -l)
    [ "$line_count" -eq 2 ]

    [[ "$output" =~ "sandbox1 [template=sb-ubuntu-noble] [image=sb-ubuntu-noble:latest]" ]]
    [[ "$output" =~ "sandbox2 [template=sb-ubuntu-noble-fw] [image=sb-ubuntu-noble-fw:latest]" ]]
}

@test "T9: plain: produces no output when no sandboxes exist" {
    create_test_project "$TEST_TEMP_DIR/project"

    project_path="$TEST_TEMP_DIR/project"
    output_format="plain"
    run sandbox_ls
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

# =============================================================================
# JSON FORMAT TESTS
# =============================================================================

@test "T10: json: displays single sandbox as JSON array" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"

    project_path="$TEST_TEMP_DIR/project"
    output_format="json"
    run sandbox_ls
    [ "$status" -eq 0 ]

    [[ "$output" =~ "[" ]]
    [[ "$output" =~ "\"sandbox_id\": \"sandbox1\"" ]]
    [[ "$output" =~ "\"template_id\": \"sb-ubuntu-noble\"" ]]
    [[ "$output" =~ "\"image\": \"sb-ubuntu-noble:latest\"" ]]
    [[ "$output" =~ "]" ]]
}

@test "T11: json: displays multiple sandboxes as JSON array" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox2" "sb-ubuntu-noble-fw" "sb-ubuntu-noble-fw:latest"

    project_path="$TEST_TEMP_DIR/project"
    output_format="json"
    run sandbox_ls
    [ "$status" -eq 0 ]

    [[ "$output" =~ "\"sandbox_id\": \"sandbox1\"" ]]
    [[ "$output" =~ "\"sandbox_id\": \"sandbox2\"" ]]
}

@test "T12: json: displays empty array when no sandboxes exist" {
    create_test_project "$TEST_TEMP_DIR/project"

    project_path="$TEST_TEMP_DIR/project"
    output_format="json"
    run sandbox_ls
    [ "$status" -eq 0 ]
    [ "$output" = "[]" ]
}

# =============================================================================
# YAML FORMAT TESTS
# =============================================================================

@test "T13: yaml: displays single sandbox as YAML list item" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"

    project_path="$TEST_TEMP_DIR/project"
    output_format="yaml"
    run sandbox_ls
    [ "$status" -eq 0 ]

    [[ "$output" =~ "- sandbox_id: sandbox1" ]]
    [[ "$output" =~ "  template_id: sb-ubuntu-noble" ]]
    [[ "$output" =~ "  image: sb-ubuntu-noble:latest" ]]
}

@test "T14: yaml: displays multiple sandboxes as YAML list" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox2" "sb-ubuntu-noble-fw" "sb-ubuntu-noble-fw:latest"

    project_path="$TEST_TEMP_DIR/project"
    output_format="yaml"
    run sandbox_ls
    [ "$status" -eq 0 ]

    [[ "$output" =~ "- sandbox_id: sandbox1" ]]
    [[ "$output" =~ "- sandbox_id: sandbox2" ]]
}

@test "T15: yaml: displays empty list when no sandboxes exist" {
    create_test_project "$TEST_TEMP_DIR/project"

    project_path="$TEST_TEMP_DIR/project"
    output_format="yaml"
    run sandbox_ls
    [ "$status" -eq 0 ]
    [ "$output" = "[]" ]
}

# =============================================================================
# ERROR HANDLING TESTS
# =============================================================================

@test "T16: fails when project path does not exist" {
    project_path="$TEST_TEMP_DIR/nonexistent"
    run sandbox_ls
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error" ]]
}

@test "T17: fails when sandboxes directory does not exist" {
    mkdir -p "$TEST_TEMP_DIR/project"
    cat > "$TEST_TEMP_DIR/project/sb-project.env" << EOF
SB_PROJECT_ID=test-project
EOF

    project_path="$TEST_TEMP_DIR/project"
    run sandbox_ls
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error" ]]
}

@test "T18: fails with unknown output format" {
    create_test_project "$TEST_TEMP_DIR/project"

    project_path="$TEST_TEMP_DIR/project"
    output_format="invalid"
    run sandbox_ls
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown output format" ]]
}

# =============================================================================
# EDGE CASE TESTS
# =============================================================================

@test "T19: handles sandbox with quoted values in sb-sandbox.env" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "my-sandbox" "sb-ubuntu-noble-fw-opensnitch" "sb-ubuntu-noble-fw-opensnitch:latest"

    project_path="$TEST_TEMP_DIR/project"
    output_format="table"
    run sandbox_ls
    [ "$status" -eq 0 ]

    [[ "$output" =~ "|my-sandbox|sb-ubuntu-noble-fw-opensnitch|sb-ubuntu-noble-fw-opensnitch:latest|" ]]
}

@test "T20: handles sandbox missing sb-sandbox.env gracefully" {
    create_test_project "$TEST_TEMP_DIR/project"
    mkdir -p "$TEST_TEMP_DIR/project/sandboxes/broken-sandbox"

    project_path="$TEST_TEMP_DIR/project"
    output_format="table"
    run sandbox_ls
    [ "$status" -eq 0 ]

    header=$(echo "$output" | head -n 1)
    [ "$header" = "|Sandbox ID|Template ID|Image|" ]

    [[ "$output" =~ "|broken-sandbox|||" ]]
}
```

---

## Task 2: Run Tests to Verify They Fail

**Step 1: Make the test runner executable**

Run: `chmod +x tests/sb-ls/unit/run-tests.sh`

**Step 2: Run the tests**

Run: `./tests/sb-ls/unit/run-tests.sh`

Expected: All tests FAIL because `sandbox_ls()` still uses the old `find -printf '%f\n'` output format and does not recognize `output_format`.

---

## Task 3: Add `-o`/`--output` Option to `parser_definition_ls()`

Add the `output_format` parameter to the getoptions parser definition so `-o`/`--output` appears in help and is parsed by the dispatch.

**File:** `bin/sb`

**Replace the existing `parser_definition_ls()` (lines 183-189):**

```bash
parser_definition_ls() {
  setup   REST error:error_init help:usage abbr:true -- "Usage: $SCRIPT_NAME compose [<sandbox>] [<options>]"
  msg -- '' 'Lists all sandboxes in the project'
  msg -- 'Options:'
  param   project_path  -p    --project-path                                                                                    -- "The path to the project directory (the ".sb" directory). If not specified, $SCRIPT_NAME will attempt to find the path based on the current directory"
  disp    :usage        -h    --help
}
```

**With:**

```bash
parser_definition_ls() {
  setup   REST error:error_init help:usage abbr:true -- "Usage: $SCRIPT_NAME ls [<options>]"
  msg -- '' 'Lists all sandboxes in the project'
  msg -- 'Options:'
  param   output_format -o    --output                                                                                          -- "Output format: table (default), plain, json, yaml"
  param   project_path  -p    --project-path                                                                                    -- "The path to the project directory (the \".sb\" directory). If not specified, $SCRIPT_NAME will attempt to find the path based on the current directory"
  disp    :usage        -h    --help
}
```

**Changes:**
- Fixed usage string from `compose [<sandbox>] [<options>]` to `ls [<options>]`
- Added `output_format` param with `-o`/`--output` flags
- Escaped quotes in project-path description for consistency

---

## Task 4: Update `sandbox_ls()` to Support All Four Output Formats

Replace the existing `sandbox_ls()` function body to collect sandbox data into arrays, then format output based on `$output_format`.

**File:** `bin/sb`

**Replace the existing `sandbox_ls()` function (lines 949-983) with:**

```bash
sandbox_ls() {

  local ls_output_format="${output_format:-table}"

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
  project_path_abs=$(readlink -f $project_path)

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

    sandbox_ids+=("$sandbox_id")
    template_ids+=("$template_id")
    images+=("$image")
  done

  # Format output
  case "$ls_output_format" in
    table)
      echo "|Sandbox ID|Template ID|Image|"
      echo "|----------|-----------|-----|"
      for i in "${!sandbox_ids[@]}"; do
        echo "|${sandbox_ids[$i]}|${template_ids[$i]}|${images[$i]}|"
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
          echo "    \"image\": \"${images[$i]}\""
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
        done
      fi
      ;;
    *)
      echo "$SCRIPT_NAME: Error: Unknown output format '$ls_output_format'. Valid formats: table, plain, json, yaml"
      exit 1
      ;;
  esac

}
```

**Design notes:**
- `ls_output_format` local variable defaults to `table` when `$output_format` is not set
- Uses `grep` + `sed` to extract values from `sb-sandbox.env` instead of `source` to avoid polluting the shell or executing arbitrary code
- Strips surrounding double quotes from values (some templates quote `SB_SANDBOX_TEMPLATE_ID`, some don't)
- Handles missing `sb-sandbox.env` gracefully by showing empty template/image values
- **table**: always prints header+separator, even with no sandboxes
- **plain**: no output when no sandboxes exist
- **json**: `[]` when empty, properly formatted JSON array with no trailing comma
- **yaml**: `[]` when empty, YAML list of mappings otherwise
- Unknown format produces an error and exits with status 1
- Error messages no longer reference `$sync_file_basename` (was a copy-paste artifact in the original code)

---

## Task 5: Run Tests to Verify They Pass

**Step 1: Run the tests**

Run: `./tests/sb-ls/unit/run-tests.sh`

Expected: All 20 tests PASS.

**Step 2: If any tests fail, fix and re-run**

Debug failures by running individual tests:
```bash
./tests/sb-ls/unit/run-tests.sh tests/sb-ls/unit/sandbox_ls.bats --filter "T<number>"
```

---

## Task 6: Manual Verification and Commit

**Step 1: Verify help output shows new -o option**

Run: `sb ls -h`

Expected: Help text shows `-o`/`--output` option with format description.

**Step 2: Manual verification (if inside a project with sandboxes)**

```bash
# Default table format
sb ls

# Explicit table format
sb ls -o table

# Plain format
sb ls -o plain

# JSON format
sb ls -o json

# YAML format
sb ls -o yaml
```

**Step 3: Commit**

```bash
git add tests/sb-ls/unit/test_helper.bash tests/sb-ls/unit/run-tests.sh tests/sb-ls/unit/sandbox_ls.bats bin/sb
git commit -m "feat: update sb ls with table/plain/json/yaml output formats

Add -o/--output option to sb ls supporting four output formats:
table (default), plain, json, yaml. Each format reads SB_SANDBOX_TEMPLATE_ID
and SB_SANDBOX_IMAGE from sandbox sb-sandbox.env files.
Add BATS unit tests covering all output formats and edge cases."
```
