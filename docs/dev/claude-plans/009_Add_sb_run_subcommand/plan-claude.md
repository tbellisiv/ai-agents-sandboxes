# Add `sb run` Subcommand - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `run` subcommand to `bin/sb` for running a one-off command in a new Docker compose container for the sandbox, wrapping `docker compose run`.

**Syntax:**
```
sb run [<sandbox-id>] [-q] [OPTIONS] COMMAND [ARGS...]
```

Where `[-q]` suppresses informational echo output and `[OPTIONS]` are docker compose run options (`--rm`, `-T`, `-d`, `-u`, `-w`, `-e`, `-v`, `-p`, `--entrypoint`, `--no-deps`, etc.) passed through directly.

**Architecture:** The `sb run` subcommand resolves the sandbox configuration using `get_sandbox_cmd_conf()`, then constructs and executes `docker compose run <service> COMMAND [ARGS...]` with all docker compose run options passed through verbatim. This mirrors the `sb exec` implementation.

**Key design decision — manual argument parsing:** Like `sb exec`, the `run` subcommand does NOT use getoptions for argument parsing. Docker compose run options (`--rm`, `-T`, `-d`, `-u`, `-w`, `-e`, `-v`, `-p`, `--entrypoint`, `--no-deps`) would be rejected as unknown options by getoptions. Instead, the dispatch block manually extracts `-q`/`--quiet`, `-p`/`--project-path`, and `-h`/`--help` from leading arguments, then passes everything else through to `docker compose run`. A `parser_definition_run()` function is still defined for consistency and for generating help text via the `usage` function.

**Note on `-p` flag:** Docker compose run has its own `-p` flag (publish ports). Since our manual parser only extracts `-p`/`--project-path` from **leading** arguments (before any non-sb option), and stops at the first unrecognized argument, docker compose's `-p` can still be passed through after the COMMAND or after the sandbox-id. Users who need to specify both project-path and publish ports should use `--project-path` to avoid ambiguity.

**Sandbox-id disambiguation:** Same heuristic as `sb exec`: if the first non-option arg doesn't start with `-`, check whether a sandbox directory with that name exists in the project. If it does, consume it as the sandbox-id. Otherwise, treat it as the COMMAND.

**Reference:** [Docker Compose run](https://docs.docker.com/reference/cli/docker/compose/run/)

---

## Plan Summary: 4 Tasks

| Task | Description | Location in `bin/sb` |
|------|-------------|----------------------|
| 1 | Register `run` command in `parser_definition()` | Line ~49 |
| 2 | Add `parser_definition_run()` function (help text only) | After `parser_definition_exec()` (~line 251) |
| 3 | Add `sandbox_run()` function | After `sandbox_exec()` (~line 1660) |
| 4 | Add `run)` case to main dispatch (manual arg parsing) | After `exec)` case (~line 2350) |

**Totals:** 1 modified file (`bin/sb`)

---

## Task 1: Register `run` Command in `parser_definition()`

Add the `run` command entry to the main parser definition so it appears in help output and is recognized as a valid subcommand.

**File:** `bin/sb`

**Change:** Add the following line after the `exec` command entry (line 49) in `parser_definition()`:

```bash
  cmd run       -- "Run a one-off command in a sandbox                        "
```

**Insert after this existing line:**
```bash
  cmd exec      -- "Execute a command in a running sandbox                    "
```

**Result:** The `parser_definition()` function's command list will include `run`.

---

## Task 2: Add `parser_definition_run()` Function

Define a getoptions parser for the `run` subcommand. This function is used **only for generating help text** (via the `usage` function). It is NOT used for actual argument parsing because docker compose run options would be rejected as unknown flags by getoptions.

**File:** `bin/sb`

**Change:** Add the following function after `parser_definition_exec()` (after line 251):

```bash
parser_definition_run() {
  setup   REST help:usage abbr:true -- \
    "Usage: $SCRIPT_NAME run [<sandbox>] [-q] [-p <project-path>] [OPTIONS] COMMAND [ARGS...]"
  msg -- '' 'Run a one-off command in a new container for the sandbox.'
  msg -- ''
  msg -- 'This creates a new container from the sandbox compose service,'
  msg -- 'runs the specified command, and then stops the container.'
  msg -- 'Unlike "exec", which runs in an already-running container,'
  msg -- '"run" starts a fresh container for the command.'
  msg -- ''
  msg -- 'All OPTIONS and ARGS after the command are passed through to'
  msg -- '"docker compose run". See "docker compose run --help" for'
  msg -- 'available options (e.g. --rm, -T, -d, -u, -w, -e, -v, --entrypoint).'
  msg -- ''
  msg -- 'If <sandbox> is not specified, the default sandbox is used.'
  msg -- 'The compose service for the sandbox is resolved automatically'
  msg -- 'from SB_COMPOSE_SERVICE in the sandbox sb-compose.env file.'
  msg -- ''
  msg -- 'Examples:'
  msg -- ''
  msg -- '  Run a command in the default sandbox:'
  msg -- "    $SCRIPT_NAME run whoami"
  msg -- ''
  msg -- '  Run a command in a specific sandbox:'
  msg -- "    $SCRIPT_NAME run mysandbox ls -la /workspace"
  msg -- ''
  msg -- '  Run and automatically remove the container afterwards:'
  msg -- "    $SCRIPT_NAME run --rm whoami"
  msg -- ''
  msg -- 'Options:'
  flag    quiet         -q    --quiet                                                                                       -- "Suppress informational output. Only output from the executed command is displayed."
  param   project_path  -p    --project-path                                                                               -- "The path to the project directory (the \".sb\" directory). If not specified, $SCRIPT_NAME will attempt to find the path based on the current directory"
  disp    :usage        -h    --help
  msg -- ''
  msg -- 'All other options are passed through to "docker compose run".'
}
```

**Design notes:**
- This parser is only invoked for help display (`-h`/`--help`)
- It is NOT used for argument parsing in the dispatch — manual parsing is used instead
- The parser still defines `-q`, `-p`, and `-h` so they appear in the generated help text

---

## Task 3: Add `sandbox_run()` Function

Add the implementation function that resolves the sandbox configuration and executes `docker compose run` with pass-through arguments.

**File:** `bin/sb`

**Change:** Add the following function after `sandbox_exec()` (after line 1660):

```bash
sandbox_run() {

  #get the sandbox config
  cmd_conf=$(get_sandbox_cmd_conf)
  if [ $? -ne 0 ]; then
    if [ -n "$cmd_conf" ]; then
      echo "$cmd_conf"
    fi
    exit 1
  fi
  eval "$cmd_conf"

  if [ -z "$quiet" ]; then
    echo "$SCRIPT_NAME: Sandbox: $__sandbox_root"
    echo "$SCRIPT_NAME: Running: docker compose -f $__compose_file run $__compose_service $@"
    echo ""
  fi
  docker compose -f $__compose_file run $__compose_service "$@"
  if [ $? -ne 0 ]; then
    if [ -z "$quiet" ]; then
      echo "$SCRIPT_NAME: Error- docker compose run failed"
    fi
    exit 1
  fi

}
```

**Design notes:**
- Follows the same pattern as `sandbox_exec()`
- Uses `get_sandbox_cmd_conf()` to resolve the sandbox configuration (compose file path, service name)
- The compose service name (`$__compose_service`) is automatically injected — the user does not need to specify it
- All arguments (`"$@"`) are passed through to `docker compose run` after the service name
- This includes any docker compose run options (`--rm`, `-T`, `-d`, `-u`, `-w`, `-e`, `-v`, `-p`, `--entrypoint`, `--no-deps`) as well as the COMMAND and its ARGS
- Echo statements are suppressed when `-q` is set

---

## Task 4: Add `run)` Case to Main Dispatch

Wire up the `run` subcommand in the main case statement. This uses **manual argument parsing** (not getoptions) to extract `-q`/`--quiet`, `-p`/`--project-path`, and `-h`/`--help` from leading arguments, determine the optional sandbox-id, and pass everything else through.

**File:** `bin/sb`

**Change:** Add the following case after the `exec)` case (after line 2350):

```bash
    run)
        # Manual arg parsing: extract -q, -p and -h from leading args,
        # then pass remaining args through to docker compose run.
        # getoptions is NOT used because docker compose run options
        # (--rm, -T, -d, -u, -w, -e, -v, -p, --entrypoint) would be
        # rejected as unknown flags.
        project_path=
        quiet=
        while [ $# -gt 0 ]; do
          case "$1" in
            -q|--quiet)
              quiet=1
              shift
              ;;
            -p|--project-path)
              project_path="$2"
              shift 2
              ;;
            -h|--help)
              eval "$(getoptions parser_definition_run)"
              usage
              exit 0
              ;;
            *)
              break
              ;;
          esac
        done

        if [ $# -eq 0 ]; then
          echo "$SCRIPT_NAME: Error: 'run' requires a command to execute"
          echo "Usage: $SCRIPT_NAME run [<sandbox>] [-q] [-p <project-path>] [OPTIONS] COMMAND [ARGS...]"
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
          echo "$SCRIPT_NAME: Error: 'run' requires a command to execute"
          echo "Usage: $SCRIPT_NAME run [<sandbox>] [-q] [-p <project-path>] [OPTIONS] COMMAND [ARGS...]"
          exit 1
        fi

        sandbox_run "$@"
        ;;
```

**Argument handling logic:**

1. **Leading option extraction:** Scan args from the beginning. If `-q` is found, set quiet mode and continue. If `-p <path>` is found, extract it and continue. If `-h`/`--help` is found, display help and exit. Stop at the first arg that is not one of these options.

2. **Sandbox-id detection:** After extracting leading options, check if the first remaining arg is an existing sandbox:
   - If the arg starts with `-`, it's a docker compose run option — skip sandbox detection, use default sandbox.
   - If the arg does NOT start with `-`, look up the project's sandboxes directory to see if a sandbox with that name exists. If found, consume the arg as sandbox-id. If not found, treat it as part of the COMMAND args (use default sandbox).

3. **Pass-through:** All remaining args after sandbox-id detection are passed to `sandbox_run()`, which forwards them to `docker compose run`.

**Why manual parsing instead of getoptions:**
- Docker compose run options (`--rm`, `-T`, `-d`, `-u <user>`, `-w <dir>`, `-e <var>`, `-v <vol>`, `-p <port>`, `--entrypoint`, `--no-deps`) would be rejected by getoptions as unknown options
- Manual parsing lets us extract only our own options (`-q`, `-p`, `-h`) and pass everything else through untouched
- The `parser_definition_run()` function is still used to generate the `usage` display for `-h`

---

## Validation

After implementation, verify with these commands (assuming a running sandbox):

```bash
# Show help
sb run -h

# Run a command in the default sandbox
sb run whoami

# Run a command with arguments
sb run ls -la /workspace

# Run in a specific sandbox
sb run mysandbox whoami

# Run with --rm to auto-remove the container
sb run --rm whoami

# Pass docker compose run options through
sb run -T cat /etc/hostname

# Run as a different user
sb run -u root whoami

# Combine sandbox-id with run options
sb run mysandbox -u root ls -la /

# Set working directory
sb run -w /tmp pwd

# Run detached
sb run -d sleep 60

# Quiet mode (suppress echo statements)
sb run -q whoami

# Verify sb --help shows run command
sb --help
```
