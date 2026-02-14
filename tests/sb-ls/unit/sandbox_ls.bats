#!/usr/bin/env bats
# sandbox_ls.bats - Unit tests for sandbox_ls() output formats

load test_helper

# =============================================================================
# TABLE FORMAT TESTS (default)
# =============================================================================

@test "T1: table: displays header with uppercase column names" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"

    project_path="$TEST_TEMP_DIR/project"
    output_format="table"
    run sandbox_ls
    [ "$status" -eq 0 ]

    header=$(echo "$output" | head -n 1)
    [[ "$header" =~ ^PROJECT\ ID ]]
    [[ "$header" =~ SANDBOX\ ID ]]
    [[ "$header" =~ TEMPLATE\ ID ]]
    [[ "$header" =~ IMAGE$ ]]
}

@test "T2: table: displays separator with dashes as second line" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"

    project_path="$TEST_TEMP_DIR/project"
    output_format="table"
    run sandbox_ls
    [ "$status" -eq 0 ]

    separator=$(echo "$output" | sed -n '2p')
    # Separator should contain only dashes and spaces
    [[ "$separator" =~ ^[-\ ]+$ ]]
    # Should have dashes for each column
    [[ "$separator" =~ ---------- ]]
    [[ "$separator" =~ ----------- ]]
    [[ "$separator" =~ -----$ ]]
}

@test "T3: table: displays single sandbox row with correct values" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"

    project_path="$TEST_TEMP_DIR/project"
    output_format="table"
    run sandbox_ls
    [ "$status" -eq 0 ]

    data_row=$(echo "$output" | sed -n '3p')
    [[ "$data_row" =~ ^test-project ]]
    [[ "$data_row" =~ sandbox1 ]]
    [[ "$data_row" =~ sb-ubuntu-noble ]]
    [[ "$data_row" =~ sb-ubuntu-noble:latest$ ]]
}

@test "T4: table: displays multiple sandboxes with aligned columns" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox2" "sb-ubuntu-noble-fw" "sb-ubuntu-noble-fw:latest"

    project_path="$TEST_TEMP_DIR/project"
    output_format="table"
    run sandbox_ls
    [ "$status" -eq 0 ]

    # Should have header + separator + 2 data rows = 4 lines
    line_count=$(echo "$output" | wc -l)
    [ "$line_count" -eq 4 ]

    [[ "$output" =~ test-project ]]
    [[ "$output" =~ sandbox1 ]]
    [[ "$output" =~ sb-ubuntu-noble:latest ]]
    [[ "$output" =~ sandbox2 ]]
    [[ "$output" =~ sb-ubuntu-noble-fw:latest ]]
}

@test "T5: table: displays header and separator when no sandboxes exist" {
    create_test_project "$TEST_TEMP_DIR/project"

    project_path="$TEST_TEMP_DIR/project"
    output_format="table"
    run sandbox_ls
    [ "$status" -eq 0 ]

    line_count=$(echo "$output" | wc -l)
    [ "$line_count" -eq 2 ]

    # With no data, column widths equal header lengths + 4-space gap
    header=$(echo "$output" | head -n 1)
    [ "$header" = "PROJECT ID      SANDBOX ID    TEMPLATE ID    IMAGE" ]

    separator=$(echo "$output" | sed -n '2p')
    [ "$separator" = "----------      ----------    -----------    -----" ]
}

@test "T6: table: is the default format when output_format is not set" {
    create_test_project "$TEST_TEMP_DIR/project"
    create_test_sandbox "$TEST_TEMP_DIR/project" "sandbox1" "sb-ubuntu-noble" "sb-ubuntu-noble:latest"

    project_path="$TEST_TEMP_DIR/project"
    output_format=
    run sandbox_ls
    [ "$status" -eq 0 ]

    header=$(echo "$output" | head -n 1)
    [[ "$header" =~ ^PROJECT\ ID ]]
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
    [[ "$output" =~ "sandbox1 [project=test-project] [template=sb-ubuntu-noble] [image=sb-ubuntu-noble:latest]" ]]
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

    [[ "$output" =~ "sandbox1 [project=test-project] [template=sb-ubuntu-noble] [image=sb-ubuntu-noble:latest]" ]]
    [[ "$output" =~ "sandbox2 [project=test-project] [template=sb-ubuntu-noble-fw] [image=sb-ubuntu-noble-fw:latest]" ]]
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
    [[ "$output" =~ "\"project_id\": \"test-project\"" ]]
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

    [[ "$output" =~ "\"project_id\": \"test-project\"" ]]
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

    [[ "$output" =~ "- project_id: test-project" ]]
    [[ "$output" =~ "  sandbox_id: sandbox1" ]]
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

    [[ "$output" =~ "- project_id: test-project" ]]
    [[ "$output" =~ "  sandbox_id: sandbox1" ]]
    [[ "$output" =~ "  sandbox_id: sandbox2" ]]
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

    [[ "$output" =~ test-project ]]
    [[ "$output" =~ my-sandbox ]]
    [[ "$output" =~ sb-ubuntu-noble-fw-opensnitch ]]
    [[ "$output" =~ sb-ubuntu-noble-fw-opensnitch:latest ]]
}

@test "T20: handles sandbox missing sb-sandbox.env gracefully" {
    create_test_project "$TEST_TEMP_DIR/project"
    mkdir -p "$TEST_TEMP_DIR/project/sandboxes/broken-sandbox"

    project_path="$TEST_TEMP_DIR/project"
    output_format="table"
    run sandbox_ls
    [ "$status" -eq 0 ]

    header=$(echo "$output" | head -n 1)
    [[ "$header" =~ ^PROJECT\ ID ]]

    # The broken sandbox row should show the project ID and sandbox ID
    [[ "$output" =~ test-project ]]
    [[ "$output" =~ broken-sandbox ]]
}
