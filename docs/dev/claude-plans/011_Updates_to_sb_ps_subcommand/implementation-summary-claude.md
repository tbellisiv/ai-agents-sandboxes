# Update `sb ps` Subcommand - Implementation Summary

## Overview

Updated the `sb ps` subcommand to display status for all sandboxes in a project (matching the output style and options of `sb ls`) with Docker container runtime data, and added `-o`/`--output` option for multiple output formats.

**Branch:** `feature/011-update-sb-ps-subcommand` (merged to `main` via fast-forward)

**Commits:**
- `478a150` — Added BATS unit test infrastructure and 23 tests for sb ps subcommand
- `c3cbc45` — Updated sb ps subcommand to display status for all project sandboxes with multi-format output

**Files changed:** 4 files, +707/-27 lines

| File | Change | Lines |
|------|--------|-------|
| `bin/sb` | Modified | +173/-27 |
| `tests/sb-ps/unit/test_helper.bash` | Created | +114 |
| `tests/sb-ps/unit/sandbox_ps.bats` | Created | +396 |
| `tests/sb-ps/unit/run-tests.sh` | Created | +24 |

---

## Implementation Steps

### Step 1: Created test infrastructure (`tests/sb-ps/unit/`)

- **`test_helper.bash`** — Shared helpers for BATS tests, following the pattern from `tests/sb-ls/unit/`. Includes:
  - Mock `docker` command that intercepts `docker compose -f <file> ps ...` calls and returns content from a `.mock-ps-output` file in the sandbox directory
  - `create_test_project()` — Creates project directory with `sb-project.env` and `sandboxes/`
  - `create_test_sandbox()` — Creates sandbox directory with `sb-sandbox.env`, `sb-compose.env`, and `docker-compose.yml`
  - `set_mock_ps_output()` — Sets mock docker compose ps response for a sandbox
  - `setup()` / `teardown()` — Per-test temp directory lifecycle with mock docker PATH injection
- **`run-tests.sh`** — Test runner using project-local BATS at `tests/tools/bats/bats-core/bin/bats`

### Step 2: Wrote 23 BATS unit tests

All tests written before implementation (TDD). Tests organized into 6 sections:

| Section | Tests | Description |
|---------|-------|-------------|
| Table format | T1-T7 | Header columns, separator line, single/multiple rows, empty list, default format, no-container sandbox |
| Plain format | T8-T10 | Single/multiple sandboxes, empty list |
| JSON format | T11-T14 | Single/multiple sandboxes, empty array, no-container empty strings |
| YAML format | T15-T17 | Single/multiple sandboxes, empty list |
| Error handling | T18-T20 | Nonexistent project path, missing sandboxes directory, unknown output format |
| Edge cases | T21-T23 | Quoted env values, missing sb-sandbox.env, missing docker-compose.yml |

### Step 3: Verified tests fail

All 23 tests failed as expected before implementation, confirming the tests correctly target the new behavior.

### Step 4: Updated `parser_definition_ps()` (`bin/sb:158-165`)

- Fixed usage string bug: `"compose [<sandbox>] [<options>]"` → `"ps [<options>]"`
- Updated description: `'Displays sandbox status'` → `'Displays status for all sandboxes in the project'`
- Added `output_format` param with `-o`/`--output` option (matching `parser_definition_ls()`)
- Fixed quoting on `--project-path` help text to use escaped quotes

### Step 5: Rewrote `sandbox_ps()` (`bin/sb:870-1046`)

Replaced the single-sandbox implementation (which used `get_sandbox_cmd_conf()` and showed one sandbox's docker compose output) with a complete rewrite that:

- Resolves project path (via `--project-path` or `dir_search_tree_up_by_dirname`)
- Validates `sb-project.env` and `sandboxes/` directory exist
- Iterates all sandbox directories, collecting data into parallel arrays:
  - **Static data** from `sb-sandbox.env` (grep+sed): `template_id`, `image`
  - **Runtime data** from `docker compose ps -a --format '{{.Name}}|{{.Status}}|{{.RunningFor}}|{{.Service}}'`: `container_name`, `status`, `created`, `service`
  - Reads `SB_COMPOSE_SERVICE` from `sb-compose.env` (grep+sed)
- Formats output in 4 modes:
  - **`table`** (default): 6 columns (`SANDBOX ID`, `STATUS`, `CREATED`, `CONTAINER_NAME`, `SERVICE`, `IMAGE`) with uppercase headers, dash separators, 4-space column gaps, dynamic column widths
  - **`plain`**: `<sandbox-id> [template=<template-id>] [image=<image>]`
  - **`json`**: JSON array with all 7 fields per sandbox
  - **`yaml`**: YAML list with all 7 fields per sandbox
- Gracefully handles missing files (sb-sandbox.env, sb-compose.env, docker-compose.yml) and sandboxes without containers (empty runtime fields)

### Step 6: Updated dispatcher (`bin/sb:2512-2516`)

Removed `sandbox=$1` and `sandbox_ps $sandbox` — replaced with just `sandbox_ps` (no arguments, matching the `sb ls` dispatcher pattern).

---

## Test Results

### sb ps tests: 23/23 PASS

```
ok 1 T1: table: displays header with uppercase column names
ok 2 T2: table: displays separator with dashes as second line
ok 3 T3: table: displays single sandbox row with correct values
ok 4 T4: table: displays multiple sandboxes with aligned columns
ok 5 T5: table: displays header and separator when no sandboxes exist
ok 6 T6: table: is the default format when output_format is not set
ok 7 T7: table: shows sandbox with no container (empty runtime fields)
ok 8 T8: plain: displays single sandbox in correct format
ok 9 T9: plain: displays multiple sandboxes
ok 10 T10: plain: produces no output when no sandboxes exist
ok 11 T11: json: displays single sandbox as JSON array with all fields
ok 12 T12: json: displays multiple sandboxes as JSON array
ok 13 T13: json: displays empty array when no sandboxes exist
ok 14 T14: json: includes empty strings for sandbox with no container
ok 15 T15: yaml: displays single sandbox as YAML list item with all fields
ok 16 T16: yaml: displays multiple sandboxes as YAML list
ok 17 T17: yaml: displays empty list when no sandboxes exist
ok 18 T18: fails when project path does not exist
ok 19 T19: fails when sandboxes directory does not exist
ok 20 T20: fails with unknown output format
ok 21 T21: handles sandbox with quoted values in sb-sandbox.env
ok 22 T22: handles sandbox missing sb-sandbox.env gracefully
ok 23 T23: handles sandbox missing docker-compose.yml (empty runtime fields)
```

### sb ls tests: 20/20 PASS (no regression)

```
ok 1 T1: table: displays header with uppercase column names
ok 2 T2: table: displays separator with dashes as second line
ok 3 T3: table: displays single sandbox row with correct values
ok 4 T4: table: displays multiple sandboxes with aligned columns
ok 5 T5: table: displays header and separator when no sandboxes exist
ok 6 T6: table: is the default format when output_format is not set
ok 7 T7: plain: displays single sandbox in correct format
ok 8 T8: plain: displays multiple sandboxes
ok 9 T9: plain: produces no output when no sandboxes exist
ok 10 T10: json: displays single sandbox as JSON array
ok 11 T11: json: displays multiple sandboxes as JSON array
ok 12 T12: json: displays empty array when no sandboxes exist
ok 13 T13: yaml: displays single sandbox as YAML list item
ok 14 T14: yaml: displays multiple sandboxes as YAML list
ok 15 T15: yaml: displays empty list when no sandboxes exist
ok 16 T16: fails when project path does not exist
ok 17 T17: fails when sandboxes directory does not exist
ok 18 T18: fails with unknown output format
ok 19 T19: handles sandbox with quoted values in sb-sandbox.env
ok 20 T20: handles sandbox missing sb-sandbox.env gracefully
```

---

## Example Output

### Table format (default): `sb ps`

```
SANDBOX ID          STATUS                      CREATED           CONTAINER_NAME                   SERVICE    IMAGE
----------          ------                      -------           --------------                   -------    -----
default             Up 19 hours (healthy)       19 hours ago      sandbox-test4-default            sandbox    sb-ubuntu-noble:latest
test                Paused                      26 hours ago      sb-ubuntu-noble-fw               sandbox    sb-ubuntu-noble-fw:latest
dev-worktree-1      Up 2 minutes (not health)   2 minutes ago     sb-ubuntu-noble-fw-opensnitch    sandbox    sb-ubuntu-noble-fw-opensnitch:latest
dev-main            Paused                      90 seconds ago    sb-ubuntu-noble                  sandbox    sb-ubuntu-noble:latest
```

### Plain format: `sb ps -o plain`

```
default [template=sb-ubuntu-noble] [image=sb-ubuntu-noble:latest]
test [template=sb-ubuntu-noble-fw] [image=sb-ubuntu-noble-fw:latest]
```

### JSON format: `sb ps -o json`

```json
[
  {
    "sandbox_id": "default",
    "template_id": "sb-ubuntu-noble",
    "image": "sb-ubuntu-noble:latest",
    "status": "Up 19 hours (healthy)",
    "created": "19 hours ago",
    "container_name": "sandbox-test4-default",
    "service": "sandbox"
  }
]
```

### YAML format: `sb ps -o yaml`

```yaml
- sandbox_id: default
  template_id: sb-ubuntu-noble
  image: sb-ubuntu-noble:latest
  status: Up 19 hours (healthy)
  created: 19 hours ago
  container_name: sandbox-test4-default
  service: sandbox
```
