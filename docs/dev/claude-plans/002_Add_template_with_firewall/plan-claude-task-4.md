# Detailed Plan: Task 4 - Add `-f` Option to `sb logs` Sub-command

## Overview

Add a `-f` (follow) option to the `sb logs` sub-command that allows users to tail/follow the sandbox container logs in real-time, similar to `docker compose logs -f` or `tail -f`.

## Problem Statement

Currently, the `sb logs` command only displays existing container logs and exits. Users who want to monitor logs in real-time must run `docker compose logs -f` directly, which requires knowing the compose file path and service name.

## Solution

Add a `-f` / `--follow` flag to the `sb logs` command that, when specified, appends the `-f` option to the underlying `docker compose logs` command.

## Current Implementation

### Parser Definition (lines 162-168)
```bash
parser_definition_logs() {
	setup   REST error:error_init help:usage abbr:true -- "Usage: $SCRIPT_NAME logs [<sandbox>] [<options>]"
	msg -- '' 'Displays sandbox container logs'
	msg -- 'Options:'
	param   project_path  -p    --project-path    -- "The path to the project directory..."
	disp    :usage        -h    --help
}
```

### Command Implementation (lines 678-695)
```bash
sandbox_logs() {
  #get the sandbox config
  cmd_conf=$(get_sandbox_cmd_conf)
  if [ $? -ne 0 ]; then
    if [ -n "$cmd_conf" ]; then
      echo "$cmd_conf"
    fi
    exit 1
  fi
  eval "$cmd_conf"

  echo "$SCRIPT_NAME: Sandbox: $__sandbox_root"
  echo "$SCRIPT_NAME: Running: docker compose $__compose_file logs $__compose_service --no-log-prefix -t --no-color"
  echo ""
  docker compose -f $__compose_file logs $__compose_service --no-log-prefix -t --no-color
}
```

### Case Dispatch (lines 1609-1614)
```bash
logs)
    cmd_parser="$(getoptions parser_definition_ps)"  # BUG: should be parser_definition_logs
    eval "$cmd_parser"
    sandbox=$1
    sandbox_logs $sandbox
    ;;
```

## Implementation Steps

### Step 1: Update parser_definition_logs() to add `-f` flag

Modify `parser_definition_logs()` at line 162 to include the follow flag:

```bash
parser_definition_logs() {
	setup   REST error:error_init help:usage abbr:true -- "Usage: $SCRIPT_NAME logs [<sandbox>] [<options>]"
	msg -- '' 'Displays sandbox container logs'
	msg -- 'Options:'
	flag    follow        -f    --follow           -- "Follow log output (tail -f style)"
	param   project_path  -p    --project-path     -- "The path to the project directory (the \".sb\" directory). If not specified, $SCRIPT_NAME will attempt to find the path based on the current directory"
	disp    :usage        -h    --help
}
```

### Step 2: Update sandbox_logs() to use the follow flag

Modify `sandbox_logs()` at line 678 to conditionally append `-f` to the docker compose command:

```bash
sandbox_logs() {

  #get the sandbox config
  cmd_conf=$(get_sandbox_cmd_conf)
  if [ $? -ne 0 ]; then
    if [ -n "$cmd_conf" ]; then
      echo "$cmd_conf"
    fi
    exit 1
  fi
  eval "$cmd_conf"

  # Build the follow option if specified
  follow_opt=""
  if [ -n "$follow" ]; then
    follow_opt="-f"
  fi

  echo "$SCRIPT_NAME: Sandbox: $__sandbox_root"
  echo "$SCRIPT_NAME: Running: docker compose -f $__compose_file logs $__compose_service --no-log-prefix -t --no-color $follow_opt"
  echo ""
  docker compose -f $__compose_file logs $__compose_service --no-log-prefix -t --no-color $follow_opt

}
```

### Step 3: Fix the case dispatch bug

Fix line 1610 to use the correct parser definition:

**Current (incorrect):**
```bash
logs)
    cmd_parser="$(getoptions parser_definition_ps)"
```

**Fixed:**
```bash
logs)
    cmd_parser="$(getoptions parser_definition_logs)"
```

## Files to Modify

| File | Action | Line(s) | Description |
|------|--------|---------|-------------|
| `bin/sb` | Edit | 162-168 | Add `-f`/`--follow` flag to `parser_definition_logs()` |
| `bin/sb` | Edit | 678-695 | Update `sandbox_logs()` to conditionally append `-f` option |
| `bin/sb` | Edit | 1610 | Fix bug: change `parser_definition_ps` to `parser_definition_logs` |

## Detailed Code Changes

### Change 1: parser_definition_logs() (around line 165)

Insert after line 165 (`msg -- 'Options:'`):
```bash
	flag    follow        -f    --follow           -- "Follow log output (tail -f style)"
```

### Change 2: sandbox_logs() (around line 689)

Insert after `eval "$cmd_conf"` (line 688) and before the echo statements:
```bash
  # Build the follow option if specified
  follow_opt=""
  if [ -n "$follow" ]; then
    follow_opt="-f"
  fi
```

Update the echo and docker compose command to include `$follow_opt`:
```bash
  echo "$SCRIPT_NAME: Running: docker compose -f $__compose_file logs $__compose_service --no-log-prefix -t --no-color $follow_opt"
  echo ""
  docker compose -f $__compose_file logs $__compose_service --no-log-prefix -t --no-color $follow_opt
```

### Change 3: Case dispatch fix (line 1610)

Replace:
```bash
    cmd_parser="$(getoptions parser_definition_ps)"
```

With:
```bash
    cmd_parser="$(getoptions parser_definition_logs)"
```

## Testing

After implementation, verify by:

1. **Check help output shows `-f` option:**
   ```bash
   sb logs --help
   ```
   Expected: Should show `-f, --follow` in the options section with description "Follow log output (tail -f style)"

2. **Test logs without `-f` (existing behavior):**
   ```bash
   sb logs
   ```
   Expected: Displays existing logs and exits immediately

3. **Test logs with `-f` flag:**
   ```bash
   sb logs -f
   ```
   Expected:
   - Displays existing logs
   - Continues to follow/tail new log output
   - User can exit with Ctrl+C
   - The echoed command should include `-f` at the end

4. **Test with `--follow` long form:**
   ```bash
   sb logs --follow
   ```
   Expected: Same behavior as `-f`

5. **Verify parser fix works:**
   ```bash
   sb logs -p /some/path
   ```
   Expected: The `-p` option should work correctly (it was broken before due to using wrong parser)

## Rationale

1. **Follows docker compose convention**: The `-f` flag mirrors the standard `docker compose logs -f` behavior that users expect
2. **Minimal change**: Only adds what's necessary without changing existing behavior
3. **Fixes existing bug**: The case dispatch was using the wrong parser, which would have caused `-p` option parsing to fail for the logs command
4. **Consistent with other flags**: Uses the `flag` directive from getoptions like other boolean options in the codebase (e.g., `confirm` in `parser_definition_rm`)
