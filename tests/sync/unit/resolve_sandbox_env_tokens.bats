#!/usr/bin/env bats
# resolve_sandbox_env_tokens.bats - Unit tests for resolve_sandbox_env_tokens()

load test_helper

# =============================================================================
# BASIC TOKEN RESOLUTION TESTS
# =============================================================================

@test "T1: Resolves a single __ENV__ token" {
    create_test_env_file "$TEST_TEMP_DIR/test.env" \
        "SB_LOGIN_USER_HOME=/home/sandbox"

    run resolve_sandbox_env_tokens "__ENV__SB_LOGIN_USER_HOME/.ssh" "$TEST_TEMP_DIR/test.env"
    [ "$status" -eq 0 ]
    [ "$output" = "/home/sandbox/.ssh" ]
}

@test "T2: Resolves multiple __ENV__ tokens in a single string" {
    create_test_env_file "$TEST_TEMP_DIR/test.env" \
        "SB_LOGIN_USER_HOME=/home/sandbox" \
        "SB_PROJECT_ID=myproject"

    run resolve_sandbox_env_tokens "__ENV__SB_LOGIN_USER_HOME/projects/__ENV__SB_PROJECT_ID" "$TEST_TEMP_DIR/test.env"
    [ "$status" -eq 0 ]
    [ "$output" = "/home/sandbox/projects/myproject" ]
}

@test "T3: Returns input unchanged when no tokens are present" {
    create_test_env_file "$TEST_TEMP_DIR/test.env" \
        "SB_LOGIN_USER_HOME=/home/sandbox"

    run resolve_sandbox_env_tokens "/tmp/some/path" "$TEST_TEMP_DIR/test.env"
    [ "$status" -eq 0 ]
    [ "$output" = "/tmp/some/path" ]
}

@test "T4: Returns empty string for empty input" {
    create_test_env_file "$TEST_TEMP_DIR/test.env" \
        "SB_LOGIN_USER_HOME=/home/sandbox"

    run resolve_sandbox_env_tokens "" "$TEST_TEMP_DIR/test.env"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

# =============================================================================
# QUOTED VALUE TESTS
# =============================================================================

@test "T5: Strips double quotes from env values" {
    create_test_env_file "$TEST_TEMP_DIR/test.env" \
        'SB_LOGIN_USER_HOME="/home/sandbox"'

    run resolve_sandbox_env_tokens "__ENV__SB_LOGIN_USER_HOME/.config" "$TEST_TEMP_DIR/test.env"
    [ "$status" -eq 0 ]
    [ "$output" = "/home/sandbox/.config" ]
}

# =============================================================================
# ERROR HANDLING TESTS
# =============================================================================

@test "T6: Fails when token references nonexistent variable" {
    create_test_env_file "$TEST_TEMP_DIR/test.env" \
        "SB_LOGIN_USER_HOME=/home/sandbox"

    run resolve_sandbox_env_tokens "__ENV__NONEXISTENT_VAR/path" "$TEST_TEMP_DIR/test.env"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not found" ]]
}

@test "T7: Fails when env file does not exist" {
    run resolve_sandbox_env_tokens "__ENV__SB_LOGIN_USER_HOME/path" "$TEST_TEMP_DIR/nonexistent.env"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "does not exist" ]]
}

# =============================================================================
# EDGE CASE TESTS
# =============================================================================

@test "T8: Resolves token that appears at the start of the string" {
    create_test_env_file "$TEST_TEMP_DIR/test.env" \
        "SB_LOGIN_USER_HOME=/home/sandbox"

    run resolve_sandbox_env_tokens "__ENV__SB_LOGIN_USER_HOME" "$TEST_TEMP_DIR/test.env"
    [ "$status" -eq 0 ]
    [ "$output" = "/home/sandbox" ]
}

@test "T9: Resolves token with underscores in variable name" {
    create_test_env_file "$TEST_TEMP_DIR/test.env" \
        "SB_MY_CUSTOM_VAR=/custom/path"

    run resolve_sandbox_env_tokens "__ENV__SB_MY_CUSTOM_VAR/sub" "$TEST_TEMP_DIR/test.env"
    [ "$status" -eq 0 ]
    [ "$output" = "/custom/path/sub" ]
}

@test "T10: Resolves same token appearing twice" {
    create_test_env_file "$TEST_TEMP_DIR/test.env" \
        "SB_LOGIN_USER_HOME=/home/sandbox"

    run resolve_sandbox_env_tokens "__ENV__SB_LOGIN_USER_HOME/a:__ENV__SB_LOGIN_USER_HOME/b" "$TEST_TEMP_DIR/test.env"
    [ "$status" -eq 0 ]
    [ "$output" = "/home/sandbox/a:/home/sandbox/b" ]
}

@test "T11: Handles env file with comment lines and blank lines" {
    cat > "$TEST_TEMP_DIR/test.env" << 'EOF'
# This is a comment
SB_PROJECT_ID=testproject

# Another comment
SB_LOGIN_USER_HOME=/home/sandbox
EOF

    run resolve_sandbox_env_tokens "__ENV__SB_LOGIN_USER_HOME/__ENV__SB_PROJECT_ID" "$TEST_TEMP_DIR/test.env"
    [ "$status" -eq 0 ]
    [ "$output" = "/home/sandbox/testproject" ]
}

@test "T12: Handles env value with spaces" {
    create_test_env_file "$TEST_TEMP_DIR/test.env" \
        'SB_LOGIN_USER_HOME="/home/my user"'

    run resolve_sandbox_env_tokens "__ENV__SB_LOGIN_USER_HOME/.ssh" "$TEST_TEMP_DIR/test.env"
    [ "$status" -eq 0 ]
    [ "$output" = "/home/my user/.ssh" ]
}
