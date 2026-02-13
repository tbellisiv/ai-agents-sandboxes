# Add `sb exec` Subcommand - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an `exec` subcommand to `bin/sb` for executing commands in a running sandbox container, wrapping `docker compose exec`.

**Syntax:**
```
sb exec [<sandbox-id>] [-p <project-path>] [OPTIONS] COMMAND [ARGS...]
```

Where `[OPTIONS]` are docker compose exec options (`-T`, `-d`, `-u`, `-w`, `-e`, `--privileged`, `--index`) passed through directly.

**Architecture:** The `sb exec` subcommand resolves the sandbox configuration using `get_sandbox_cmd_conf()`, then constructs and executes `docker compose exec <service> COMMAND [ARGS...]` with all docker compose exec options passed through verbatim.

**Key design decision — manual argument parsing:** Unlike other `sb` subcommands, `exec` does NOT use getoptions for argument parsing. This is because docker compose exec options (`-T`, `-d`, `-u`, `-w`, `-e`) would be rejected as unknown options by getoptions. Instead, the dispatch block manually extracts `-p`/`--project-path` and `-h`/`--help` from leading arguments, then passes everything else through to `docker compose exec`. A `parser_definition_exec()` function is still defined for consistency and for generating help text via the `usage` function.

**Sandbox-id disambiguation:** Since the optional `[sandbox-id]` is a positional arg followed by variable-length pass-through args, the dispatch block uses a heuristic: if the first non-option arg doesn't start with `-`, it checks whether a sandbox directory with that name exists in the project. If it does, the arg is consumed as the sandbox-id. Otherwise, it's treated as the COMMAND (part of the docker compose exec args).

**Reference:** [Docker Compose exec](https://docs.docker.com/reference/cli/docker/compose/exec/)

---

## Plan Summary: 4 Tasks

| Task | Description | Location in `bin/sb` |
|------|-------------|----------------------|
| 1 | Register `exec` command in `parser_definition()` | Line ~48 |
| 2 | Add `parser_definition_exec()` function (help text only) | After `parser_definition_cp()` (~line 221) |
| 3 | Add `sandbox_exec()` function | After `sandbox_cp()` (~line 1603) |
| 4 | Add `exec)` case to main dispatch (manual arg parsing) | After `cp)` case (~line 2236) |

**Totals:** 1 modified file (`bin/sb`)

---

## Task 1: Register `exec` Command in `parser_definition()`

Add the `exec` command entry to the main parser definition so it appears in help output and is recognized as a valid subcommand.

**File:** `bin/sb`

**Change:** Add the following line after the `cp` command entry (line 48) in `parser_definition()`:

```bash
  cmd exec      -- "Execute a command in a running sandbox                    "
```

**Insert after this existing line:**
```bash
  cmd cp        -- "Copy files between host and sandbox                        "
```

**Result:** The `parser_definition()` function's command list will include `exec`.

---

## Task 2: Add `parser_definition_exec()` Function

Define a getoptions parser for the `exec` subcommand. This function is used **only for generating help text** (via the `usage` function). It is NOT used for actual argument parsing because docker compose exec options would be rejected as unknown flags by getoptions.

**File:** `bin/sb`

**Change:** Add the following function after `parser_definition_cp()` (after line 221):

```bash
parser_definition_exec() {
  setup   REST help:usage abbr:true -- \
    "Usage: $SCRIPT_NAME exec [<sandbox>] [-p <project-path>] [OPTIONS] COMMAND [ARGS...]"
  msg -- '' 'Execute a command in a running sandbox container.'
  msg -- ''
  msg -- 'All OPTIONS and ARGS after the command are passed through to'
  msg -- '"docker compose exec". See "docker compose exec --help" for'
  msg -- 'available options (e.g. -T, -d, -u, -w, -e).'
  msg -- ''
  msg -- 'If <sandbox> is not specified, the default sandbox is used.'
  msg -- 'The compose service for the sandbox is resolved automatically'
  msg -- 'from SB_COMPOSE_SERVICE in the sandbox sb-compose.env file.'
  msg -- ''
  msg -- 'Examples:'
  msg -- ''
  msg -- '  Run a command in the default sandbox:'
  msg -- "    $SCRIPT_NAME exec ls -la /workspace"
  msg -- ''
  msg -- '  Run a command in a specific sandbox:'
  msg -- "    $SCRIPT_NAME exec mysandbox whoami"
  msg -- ''
  msg -- 'Options:'
  param   project_path  -p    --project-path                                                                               -- "The path to the project directory (the \".sb\" directory). If not specified, $SCRIPT_NAME will attempt to find the path based on the current directory"
  disp    :usage        -h    --help
  msg -- ''
  msg -- 'All other options are passed through to "docker compose exec".'
}
```

**Design notes:**
- This parser is only invoked for help display (`-h`/`--help`)
- It is NOT used for argument parsing in the dispatch — manual parsing is used instead
- The parser still defines `-p` and `-h` so they appear in the generated help text

---

## Task 3: Add `sandbox_exec()` Function

Add the implementation function that resolves the sandbox configuration and executes `docker compose exec` with pass-through arguments.

**File:** `bin/sb`

**Change:** Add the following function after `sandbox_cp()` (after line 1603):

```bash
sandbox_exec() {

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
  echo "$SCRIPT_NAME: Running: docker compose -f $__compose_file exec $__compose_service $@"
  echo ""
  docker compose -f $__compose_file exec $__compose_service "$@"
  if [ $? -ne 0 ]; then
    echo "$SCRIPT_NAME: Error- docker compose exec failed"
    exit 1
  fi

}
```

**Design notes:**
- Follows the same pattern as `sandbox_compose()` and `sandbox_cp()`
- Uses `get_sandbox_cmd_conf()` to resolve the sandbox configuration (compose file path, service name)
- The compose service name (`$__compose_service`) is automatically injected — the user does not need to specify it
- All arguments (`"$@"`) are passed through to `docker compose exec` after the service name
- This includes any docker compose exec options (`-T`, `-d`, `-u`, `-w`, `-e`, `--privileged`) as well as the COMMAND and its ARGS

---

## Task 4: Add `exec)` Case to Main Dispatch

Wire up the `exec` subcommand in the main case statement. This uses **manual argument parsing** (not getoptions) to extract `-p`/`--project-path` and `-h`/`--help` from leading arguments, determine the optional sandbox-id, and pass everything else through.

**File:** `bin/sb`

**Change:** Add the following case after the `cp)` case (after line 2236):

```bash
    exec)
        # Manual arg parsing: extract -p and -h from leading args,
        # then pass remaining args through to docker compose exec.
        # getoptions is NOT used because docker compose exec options
        # (-T, -d, -u, -w, -e) would be rejected as unknown flags.
        project_path=
        while [ $# -gt 0 ]; do
          case "$1" in
            -p|--project-path)
              project_path="$2"
              shift 2
              ;;
            -h|--help)
              eval "$(getoptions parser_definition_exec)"
              usage
              exit 0
              ;;
            *)
              break
              ;;
          esac
        done

        if [ $# -eq 0 ]; then
          echo "$SCRIPT_NAME: Error: 'exec' requires a command to execute"
          echo "Usage: $SCRIPT_NAME exec [<sandbox>] [-p <project-path>] [OPTIONS] COMMAND [ARGS...]"
          exit 1
        fi

        # Determine if first arg is a sandbox-id.
        # Heuristic: if first arg doesn't start with '-' and a sandbox
        # directory with that name exists, treat it as the sandbox-id.
        sandbox=
        if [[ ! "$1" =~ ^- ]]; then
          _proj_path="${project_path:-$(dir_search_tree_up_by_dirname ".sb")}"
          if [ -n "$_proj_path" ]; then
            _proj_path_abs=$(readlink -f "$_proj_path")
            if [ -d "$_proj_path_abs/sandboxes/$1" ]; then
              sandbox="$1"
              shift
            fi
          fi
        fi

        if [ $# -eq 0 ]; then
          echo "$SCRIPT_NAME: Error: 'exec' requires a command to execute"
          echo "Usage: $SCRIPT_NAME exec [<sandbox>] [-p <project-path>] [OPTIONS] COMMAND [ARGS...]"
          exit 1
        fi

        sandbox_exec "$@"
        ;;
```

**Argument handling logic:**

1. **Leading option extraction:** Scan args from the beginning. If `-p <path>` is found, extract it and continue. If `-h`/`--help` is found, display help and exit. Stop at the first arg that is not one of these options.

2. **Sandbox-id detection:** After extracting leading options, check if the first remaining arg is an existing sandbox:
   - If the arg starts with `-`, it's a docker compose exec option — skip sandbox detection, use default sandbox.
   - If the arg does NOT start with `-`, look up the project's sandboxes directory to see if a sandbox with that name exists. If found, consume the arg as sandbox-id. If not found, treat it as part of the COMMAND args (use default sandbox).

3. **Pass-through:** All remaining args after sandbox-id detection are passed to `sandbox_exec()`, which forwards them to `docker compose exec`.

**Why manual parsing instead of getoptions:**
- Docker compose exec options (`-T`, `-d`, `-u <user>`, `-w <dir>`, `-e <var>`) would be rejected by getoptions as unknown options
- Manual parsing lets us extract only our own options (`-p`, `-h`) and pass everything else through untouched
- The `parser_definition_exec()` function is still used to generate the `usage` display for `-h`

---

## Validation

After implementation, verify with these commands (assuming a running sandbox):

```bash
# Show help
sb exec -h

# Run a command in the default sandbox
sb exec whoami

# Run a command with arguments
sb exec ls -la /workspace

# Run in a specific sandbox
sb exec mysandbox whoami

# Pass docker compose exec options through
sb exec -T cat /etc/hostname

# Run as a different user
sb exec -u root whoami

# Combine sandbox-id with exec options
sb exec mysandbox -u root ls -la /

# Set working directory
sb exec -w /tmp pwd

# Run detached
sb exec -d sleep 60

# Verify sb --help shows exec command
sb --help
```
