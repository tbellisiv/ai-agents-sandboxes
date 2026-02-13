# Add `sb cp` Subcommand - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `cp` subcommand to `bin/sb` for copying files between the host and a sandbox container, wrapping `docker compose cp`.

**Syntax:**
```
sb cp [<sandbox-id>] [-a] [-L] [-p <project-path>] <compose-service>:<src-path> <dest-path>
sb cp [<sandbox-id>] [-a] [-L] [-p <project-path>] <src-path> <compose-service>:<dest-path>
```

**Architecture:** The `sb cp` subcommand resolves the sandbox configuration (compose file, service name) using the existing `get_sandbox_cmd_conf()` pattern, then constructs and executes a `docker compose cp` command with the resolved compose file and any pass-through flags (`-a`, `-L`).

**Reference:** [Docker Compose cp](https://docs.docker.com/reference/cli/docker/compose/cp/)

---

## Plan Summary: 4 Tasks

| Task | Description | Location in `bin/sb` |
|------|-------------|----------------------|
| 1 | Register `cp` command in `parser_definition()` | Line ~47 |
| 2 | Add `parser_definition_cp()` function | After `parser_definition_compose()` (~line 195) |
| 3 | Add `sandbox_cp()` function | After `sandbox_compose()` (~line 1535) |
| 4 | Add `cp)` case to main dispatch | After `compose)` case (~line 2152) |

**Totals:** 1 modified file (`bin/sb`)

---

## Task 1: Register `cp` Command in `parser_definition()`

Add the `cp` command entry to the main parser definition so it appears in help output and is recognized as a valid subcommand.

**File:** `bin/sb`

**Change:** Add the following line after the `compose` command entry (line 47) in `parser_definition()`:

```bash
  cmd cp        -- "Copy files between host and sandbox                        "
```

**Insert after this existing line:**
```bash
  cmd compose   -- "Runs a docker compose command                              "
```

**Result:** The `parser_definition()` function's command list will include `cp`.

---

## Task 2: Add `parser_definition_cp()` Function

Define the getoptions parser for the `cp` subcommand. This parser handles:
- `-a` / `--archive` flag (pass-through to `docker compose cp`)
- `-L` / `--follow-link` flag (pass-through to `docker compose cp`)
- `-p` / `--project-path` param (standard across all subcommands)
- `-h` / `--help` display

**File:** `bin/sb`

**Change:** Add the following function after `parser_definition_compose()` (after line 195):

```bash
parser_definition_cp() {
  setup   REST error:error_init help:usage abbr:true -- \
    "Usage: $SCRIPT_NAME cp [<sandbox>] [-a] [-L] [-p <project-path>] <service:src> <dest>" \
    "       $SCRIPT_NAME cp [<sandbox>] [-a] [-L] [-p <project-path>] <src> <service:dest>"
  msg -- '' 'Copies files/directories between the host and a sandbox container.'
  msg -- ''
  msg -- 'The source or destination must include the compose service name prefix'
  msg -- '(e.g., "myservice:/path/in/container"). The compose service name for a'
  msg -- 'sandbox is defined in SB_COMPOSE_SERVICE in the sandbox sb-compose.env file.'
  msg -- ''
  msg -- 'Examples:'
  msg -- ''
  msg -- '  Copy a file from the host to the sandbox:'
  msg -- "    $SCRIPT_NAME cp ./config.json myservice:/workspace/project/config.json"
  msg -- ''
  msg -- '  Copy a directory from the sandbox to the host:'
  msg -- "    $SCRIPT_NAME cp myservice:/workspace/project/output ./output"
  msg -- ''
  msg -- 'Options:'
  flag    archive       -a    --archive                                                                                    -- "Archive mode (copy all uid/gid information)"
  flag    follow_link   -L    --follow-link                                                                                -- "Always follow symbol link in SRC_PATH"
  param   project_path  -p    --project-path                                                                               -- "The path to the project directory (the \".sb\" directory). If not specified, $SCRIPT_NAME will attempt to find the path based on the current directory"
  disp    :usage        -h    --help
}
```

**Design notes:**
- The `archive` and `follow_link` variables are set by the `-a` and `-L` flags respectively
- These are used in `sandbox_cp()` to construct the `docker compose cp` options
- Positional arguments (`<sandbox-id>`, `<src>`, `<dest>`) are handled in the main dispatch (Task 4), not by getoptions

---

## Task 3: Add `sandbox_cp()` Function

Add the main implementation function that resolves the sandbox configuration and executes the `docker compose cp` command.

**File:** `bin/sb`

**Change:** Add the following function after `sandbox_compose()` (after line 1535):

```bash
sandbox_cp() {

  local src_path="$1"
  local dest_path="$2"

  if [ -z "$src_path" ] || [ -z "$dest_path" ]; then
    echo "$SCRIPT_NAME: Error: 'cp' requires source and destination path arguments"
    echo "Usage: $SCRIPT_NAME cp [<sandbox>] [-a] [-L] <service:src> <dest>"
    echo "       $SCRIPT_NAME cp [<sandbox>] [-a] [-L] <src> <service:dest>"
    exit 1
  fi

  #get the sandbox config
  cmd_conf=$(get_sandbox_cmd_conf)
  if [ $? -ne 0 ]; then
    if [ -n "$cmd_conf" ]; then
      echo "$cmd_conf"
    fi
    exit 1
  fi
  eval "$cmd_conf"

  # Build docker compose cp options
  local cp_opts=""
  if [ -n "$archive" ]; then
    cp_opts="$cp_opts -a"
  fi
  if [ -n "$follow_link" ]; then
    cp_opts="$cp_opts -L"
  fi

  echo "$SCRIPT_NAME: Sandbox: $__sandbox_root"
  echo "$SCRIPT_NAME: Running: docker compose -f $__compose_file cp${cp_opts} $src_path $dest_path"
  echo ""
  docker compose -f $__compose_file cp $cp_opts "$src_path" "$dest_path"
  if [ $? -ne 0 ]; then
    echo "$SCRIPT_NAME: Error- docker compose cp failed"
    exit 1
  fi

}
```

**Design notes:**
- Follows the same pattern as `sandbox_compose()` and other subcommand functions
- Uses `get_sandbox_cmd_conf()` to resolve the sandbox configuration (compose file path, etc.)
- The `archive` and `follow_link` variables are globals set by getoptions in `parser_definition_cp()`
- The `$cp_opts` string is intentionally unquoted in the `docker compose` call so that empty options don't produce empty arguments
- The source and destination paths are passed through directly to `docker compose cp` (they include the `service:path` notation as typed by the user)

---

## Task 4: Add `cp)` Case to Main Dispatch

Wire up the `cp` subcommand in the main case statement. This handles the special positional argument logic: determining whether the first positional argument is a sandbox ID or a path argument.

**File:** `bin/sb`

**Change:** Add the following case after the `compose)` case (after line 2152):

```bash
    cp)
        cmd_parser="$(getoptions parser_definition_cp)"
        eval "$cmd_parser"
        if [ $# -ge 3 ]; then
          sandbox=$1
          sandbox_cp "$2" "$3"
        elif [ $# -eq 2 ]; then
          sandbox=
          sandbox_cp "$1" "$2"
        else
          echo "$SCRIPT_NAME: Error: 'cp' requires source and destination path arguments"
          echo "Usage: $SCRIPT_NAME cp [<sandbox>] [-a] [-L] <service:src> <dest>"
          echo "       $SCRIPT_NAME cp [<sandbox>] [-a] [-L] <src> <service:dest>"
          exit 1
        fi
        ;;
```

**Positional argument handling logic:**
- After getoptions parses out `-a`, `-L`, and `-p`, the remaining positional arguments are:
  - **3 args:** `$1` = sandbox-id, `$2` = src-path, `$3` = dest-path
  - **2 args:** `$1` = src-path, `$2` = dest-path (sandbox resolved from default)
  - **< 2 args:** Error — missing required source/destination paths

**Note:** The `sandbox` variable is set as a global (matching the pattern used by all other subcommands) before calling `sandbox_cp()`. The `get_sandbox_cmd_conf()` function inside `sandbox_cp()` reads this global to resolve the sandbox configuration.

---

## Validation

After implementation, verify with these commands (assuming a running sandbox with compose service name from `SB_COMPOSE_SERVICE`):

```bash
# Show help
sb cp -h

# Copy file from host to container (default sandbox)
sb cp /tmp/test.txt myservice:/tmp/test.txt

# Copy file from container to host (default sandbox)
sb cp myservice:/tmp/test.txt /tmp/from-container.txt

# Copy with specific sandbox ID
sb cp mysandbox myservice:/tmp/test.txt /tmp/from-container.txt

# Copy with archive mode
sb cp -a myservice:/tmp/test.txt /tmp/from-container.txt

# Copy with follow-link
sb cp -L /tmp/test.txt myservice:/tmp/test.txt

# Copy with both flags and specific sandbox
sb cp mysandbox -a -L /tmp/test.txt myservice:/tmp/test.txt

# Verify sb --help shows cp command
sb --help
```
