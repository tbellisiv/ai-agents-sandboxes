# Task 1: Add `sb env` sub-command

## Overview

Add an `env` sub-command to `bin/sb` that prints the contents of the Docker Compose `.env` file for the active sandbox. The implementation requires 4 changes to `bin/sb`, all following established patterns used by existing sub-commands.

## Changes

### 1. Register the `env` command in `parser_definition()` (line ~46)

Add a `cmd env` entry to the commands list in `parser_definition()`, between `logs` and `ps` (or at another appropriate position among the commands).

**Location:** `bin/sb:41` (after the `cmd logs` line)

**Code to add:**

```bash
	cmd env       -- "Prints the Docker Compose .env file for a sandbox           "
```

**Pattern reference:** Existing `cmd` entries at `bin/sb:32-46`.

---

### 2. Add `parser_definition_env()` function

Add a parser definition function for the `env` sub-command. It should accept an optional `[<sandbox>]` positional argument and the standard `-p`/`--project-path` and `-h`/`--help` options.

**Location:** After `parser_definition_logs()` (after `bin/sb:169`).

**Code to add:**

```bash
parser_definition_env() {
	setup   REST error:error_init help:usage abbr:true -- "Usage: $SCRIPT_NAME env [<sandbox>] [<options>]"
	msg -- '' 'Prints the Docker Compose .env file for a sandbox'
	msg -- 'Options:'
	param   project_path  -p    --project-path                                                                                    -- "The path to the project directory (the \".sb\" directory). If not specified, $SCRIPT_NAME will attempt to find the path based on the current directory"
	disp    :usage        -h    --help
}
```

**Pattern reference:** `parser_definition_logs()` at `bin/sb:162-169` (same structure minus the `-f`/`--follow` flag).

---

### 3. Add `sandbox_env()` function

Add the function that implements the `env` command logic. It should:

1. Call `get_sandbox_cmd_conf()` to resolve the sandbox configuration (which sets `__compose_env_path` to `$sandbox_path/.env` at `bin/sb:429`).
2. Check if the `.env` file exists at `__compose_env_path`.
3. If it exists, print the file contents with `cat`.
4. If it does not exist, print an error message and exit with code 1.

**Location:** After `sandbox_logs()` (after `bin/sb:702`).

**Code to add:**

```bash
sandbox_env() {

  #get the sandbox config
  cmd_conf=$(get_sandbox_cmd_conf)
  if [ $? -ne 0 ]; then
    if [ -n "$cmd_conf" ]; then
      echo "$cmd_conf"
    fi
    exit 1
  fi
  eval "$cmd_conf"

  if [ ! -f "$__compose_env_path" ]; then
    echo "$SCRIPT_NAME: Error: Docker Compose .env file '$__compose_env_path' does not exist for sandbox '$__sandbox_id'"
    exit 1
  fi

  echo "$SCRIPT_NAME: Sandbox: $__sandbox_root"
  echo "$SCRIPT_NAME: Docker Compose .env file: $__compose_env_path"
  echo ""
  cat $__compose_env_path

}
```

**Pattern reference:** `sandbox_logs()` at `bin/sb:679-702`. The initial `get_sandbox_cmd_conf()` call and error handling is identical. The file-existence check and `cat` output replaces the `docker compose logs` invocation.

**Key variable:** `__compose_env_path` is set by `get_sandbox_cmd_conf()` at `bin/sb:429` to `$sandbox_path/.env`.

---

### 4. Add `env)` case to the main dispatch block (line ~1639)

Add a case entry for the `env` command in the main dispatch `case` statement. It should parse arguments with `parser_definition_env`, extract the optional sandbox ID, and call `sandbox_env`.

**Location:** After the `logs)` case (after `bin/sb:1621`), or before the `compose)` case.

**Code to add:**

```bash
		env)
				cmd_parser="$(getoptions parser_definition_env)"
        eval "$cmd_parser"
        sandbox=$1
        sandbox_env $sandbox
				;;
```

**Pattern reference:** `logs)` case at `bin/sb:1616-1621`.

---

## Verification

After implementation, verify the following:

- `sb --help` lists the `env` command in the commands list
- `sb env --help` displays the usage/help text for the `env` sub-command
- `sb env` prints the `.env` file contents for the default sandbox
- `sb env <sandbox-id>` prints the `.env` file contents for the specified sandbox
- `sb env <sandbox-id>` prints an error when the `.env` file does not exist
- `sb env -p <path>` works with an explicit project path
