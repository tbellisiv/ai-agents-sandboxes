# Implementation Summary: Add rsync-based File Sync to `sb sync`

## Overview

Added a `sync_files()` function to `bin/sb` that reads YAML sync specifications and uses `rsync` + `docker compose cp` to copy files from the host filesystem into sandbox containers. The function integrates into the existing `sandbox_sync()` flow and supports three YAML file sources processed in order: sandbox-level, project-level, and user-level.

## Modified Files

### `bin/sb`

Four additions were made to this file:

#### 1. `check_sync_dependencies()` (after existing helper functions, before `get_default_sandbox_id`)

Verifies that `yq` and `rsync` are installed on the host. Uses `return` (not `exit`) so the caller can decide how to handle the failure. Reports missing tool names with install instructions for `yq`.

#### 2. `resolve_sandbox_env_tokens()` (immediately after `check_sync_dependencies`)

Replaces `__ENV__<VARIABLE_NAME>` tokens in a string with values from the sandbox `.env` file.

- **Signature:** `resolve_sandbox_env_tokens <string> <env-file-path>`
- Finds all tokens matching regex `__ENV__[A-Za-z_][A-Za-z0-9_]*` in the input string
- Looks up each variable name (with `__ENV__` prefix stripped) in the `.env` file via `grep`
- Strips surrounding double quotes from values
- Replaces all occurrences of each token with the resolved value
- Returns 1 if any token cannot be resolved or the env file does not exist
- Outputs the resolved string via `echo -n`

#### 3. `sync_files()` (before `sandbox_sync()`)

Main file sync function that processes a single YAML sync specification file.

- **Signature:** `sync_files <yaml-file-path>`
- **Globals used:** `$__compose_file`, `$__compose_env_path`, `$__compose_service`, `$__sandbox_root`, `$__sandbox_id` (set by `get_sandbox_cmd_conf` + `eval`)

For each spec entry in the YAML file:

1. Parses `sandbox.path`, `host.path[]`, `sandbox.include[]`, `sandbox.exclude[]` using `yq`
2. Expands Bash variables in host paths (e.g., `$HOME`) via `eval echo`
3. Resolves `__ENV__` tokens in the sandbox path via `resolve_sandbox_env_tokens`
4. Validates that host paths exist (warns and skips missing ones)
5. Creates a temp staging directory (`/tmp/sb-sync-<sandbox-id>-XXXXXX`)
6. Builds rsync arguments:
   - Base flags: `-rLptgoD`
   - `--include=PATTERN` for each include entry (in order)
   - `--exclude=PATTERN` for each exclude entry (in order)
   - `--exclude=*` catch-all appended when includes are present
   - Source paths and temp directory destination
7. Executes rsync, logging output to `$__sandbox_root/logs/sync-rsync-<timestamp>-spec<i>.log`
8. If no files were matched, prints info message and skips `docker compose cp`
9. Executes `docker compose cp` to copy staged files into the container, logging output to `$__sandbox_root/logs/sync-compose-cp-<timestamp>-spec<i>.log`
10. On success: deletes temp directory. On failure: preserves temp directory and prints paths to temp dir and log files for debugging.

Returns 0 if all entries succeeded, 1 if any failed.

#### 4. Integration in `sandbox_sync()` (after `docker compose create -y`)

After the container is created (in `created` state, not yet running), the following sync YAML files are processed in order:

1. **Sandbox-level:** `$__sandbox_root/sb-sandbox-sync.yml`
2. **Project-level:** `$__project_root/sb-project-sync.yml`
3. **User-level:** `$__user_env_root/user-sync.yml`

Each file is only processed if it exists. File sync failures produce warnings but do not abort the overall `sb sync` operation.

## New Files

### `tests/sync/unit/test_helper.bash`

Shared test helper for Bats unit tests. Sources the helper functions (`check_sync_dependencies`, `resolve_sandbox_env_tokens`) from `bin/sb` using `sed` extraction. Provides `setup`/`teardown` functions that create and clean up temporary directories, and a `create_test_env_file` helper for building test `.env` fixtures.

### `tests/sync/unit/resolve_sandbox_env_tokens.bats`

Bats test suite with 12 test cases for `resolve_sandbox_env_tokens`:

| Test | Description |
|------|-------------|
| T1 | Resolves a single `__ENV__` token |
| T2 | Resolves multiple `__ENV__` tokens in a single string |
| T3 | Returns input unchanged when no tokens are present |
| T4 | Returns empty string for empty input |
| T5 | Strips double quotes from env values |
| T6 | Fails when token references nonexistent variable |
| T7 | Fails when env file does not exist |
| T8 | Resolves token that appears at the start of the string |
| T9 | Resolves token with underscores in variable name |
| T10 | Resolves same token appearing twice in one string |
| T11 | Handles env file with comment lines and blank lines |
| T12 | Handles env value with spaces |

### `tests/sync/unit/run-tests.sh`

Executable test runner script. Checks for `bats` installation, then runs all `.bats` files in the directory (or a specific file if passed as an argument).

## YAML Sync File Format

All three sync files (sandbox, project, user) use the same YAML structure:

```yaml
sync:
  spec:
    - host:
        path:
          - $HOME/.ssh/my_key
      sandbox:
        path: __ENV__SB_LOGIN_USER_HOME/.ssh
    - host:
        path:
          - $HOME/.config
      sandbox:
        path: __ENV__SB_LOGIN_USER_HOME
        include:
          - '*.env'
          - 'tmux/***'
        exclude:
          - '**/*secrets*'
```

- `host.path`: Array of host filesystem paths. Bash variable interpolation is supported.
- `sandbox.path`: Container destination path. `__ENV__` token prefix resolves variables from the sandbox `.env` file.
- `sandbox.include`: Optional array of rsync include patterns.
- `sandbox.exclude`: Optional array of rsync exclude patterns.

## Verification

### Automated Tests

Requires [bats-core](https://github.com/bats-core/bats-core) to be installed:

```bash
cd tests/sync/unit
./run-tests.sh
```

### Manual Tests

1. Create a sync YAML file at any of the three levels (sandbox, project, user)
2. Run `sb sync`
3. Verify files appear in the container via `sb shell` + `ls`
4. Check log files in `<sandbox-root>/logs/` for rsync and docker compose cp output
5. Test edge cases: missing host paths, missing `yq`/`rsync`, empty spec arrays, unresolvable `__ENV__` tokens
