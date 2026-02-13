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
