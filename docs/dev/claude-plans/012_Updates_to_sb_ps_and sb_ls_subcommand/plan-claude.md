# Implementation Plan: Add PROJECT ID Column to `sb ps` and `sb ls`

## Objective

Add a `PROJECT ID` column (first column) to the output of both `sb ps` and `sb ls` subcommands across all output formats (table, plain, json, yaml, minimal).

The `PROJECT ID` value is read from `SB_PROJECT_ID` in `sb-project.env`.

## Tasks

### Task 1: Update `sandbox_ps()` in `bin/sb` — Read `SB_PROJECT_ID`

**File:** `bin/sb` (function `sandbox_ps()`, line ~870)

After `sb-project.env` is validated (line ~896), read `SB_PROJECT_ID` from it using the same `grep+sed` pattern used elsewhere in the function:

```bash
local project_id=""
project_id=$(grep '^SB_PROJECT_ID=' "$project_env_path" | head -1 | sed 's/^SB_PROJECT_ID=//' | sed 's/^"//;s/"$//')
```

This goes after line 896 (the `sb-project.env` existence check), before the sandboxes loop.

### Task 2: Update `sandbox_ps()` — Add PROJECT ID to `table` format

**File:** `bin/sb` (function `sandbox_ps()`, `table` case, line ~960)

- Add `PROJECT ID` as the first column header (`h0="PROJECT ID"`)
- Compute its width (`w0`) — since all rows have the same project ID, use `max(${#h0}, ${#project_id})`
- Add column width with 4-space gap (`cw0`)
- Prepend `PROJECT ID` to header, separator, and data row `printf` calls

Expected output:
```
PROJECT ID    SANDBOX ID    STATUS    CREATED    CONTAINER_NAME    SERVICE    IMAGE
----------    ----------    ------    -------    --------------    -------    -----
test4         default       Up 19h    19h ago    sandbox-test4-d   sandbox    sb-ubuntu-noble:latest
```

### Task 3: Update `sandbox_ps()` — Add `project_id` to `plain` format

**File:** `bin/sb` (function `sandbox_ps()`, `plain` case, line ~998)

Change from:
```bash
echo "${sandbox_ids[$i]} [template=${template_ids[$i]}] [image=${images[$i]}]"
```
To:
```bash
echo "${sandbox_ids[$i]} [project=${project_id}] [template=${template_ids[$i]}] [image=${images[$i]}]"
```

### Task 4: Update `sandbox_ps()` — Add `project_id` to `json` format

**File:** `bin/sb` (function `sandbox_ps()`, `json` case, line ~1003)

Add `"project_id": "$project_id"` as the first field in each JSON object.

### Task 5: Update `sandbox_ps()` — Add `project_id` to `yaml` format

**File:** `bin/sb` (function `sandbox_ps()`, `yaml` case, line ~1025)

Add `project_id: $project_id` as the first field in each YAML list item (before `sandbox_id`).

### Task 6: Update `sandbox_ls()` in `bin/sb` — Read `SB_PROJECT_ID`

**File:** `bin/sb` (function `sandbox_ls()`, line ~1097)

Same approach as Task 1 — read `SB_PROJECT_ID` from `sb-project.env` after the existence check (line ~1123).

### Task 7: Update `sandbox_ls()` — Add PROJECT ID to `table` format

**File:** `bin/sb` (function `sandbox_ls()`, `table` case, line ~1160)

- Add `PROJECT ID` as first column header
- Compute width (same value for all rows)
- Prepend to header, separator, and data row `printf`

Expected output:
```
PROJECT ID    SANDBOX ID    TEMPLATE ID                      IMAGE
----------    ----------    -----------                      -----
test4         default       sb-ubuntu-noble-fw-opensnitch    sb-ubuntu-noble-fw-opensnitch:latest
```

### Task 8: Update `sandbox_ls()` — Add `project_id` to `plain` format

**File:** `bin/sb` (function `sandbox_ls()`, `plain` case, line ~1195)

Change from:
```bash
echo "${sandbox_ids[$i]} [template=${template_ids[$i]}] [image=${images[$i]}]"
```
To:
```bash
echo "${sandbox_ids[$i]} [project=${project_id}] [template=${template_ids[$i]}] [image=${images[$i]}]"
```

### Task 9: Update `sandbox_ls()` — Add `project_id` to `json` format

**File:** `bin/sb` (function `sandbox_ls()`, `json` case, line ~1200)

Add `"project_id": "$project_id"` as the first field in each JSON object.

### Task 10: Update `sandbox_ls()` — Add `project_id` to `yaml` format

**File:** `bin/sb` (function `sandbox_ls()`, `yaml` case, line ~1218)

Add `project_id: $project_id` as the first field in each YAML list item.

### Task 11: Update `sb ps` unit tests

**File:** `tests/sb-ps/unit/sandbox_ps.bats`

Update existing tests to expect the new `PROJECT ID` column:

- **T1**: Header now starts with `PROJECT ID`
- **T2**: Separator has dashes for PROJECT ID column
- **T3**: Data row starts with project ID value
- **T5**: Empty table header/separator includes PROJECT ID
- **T8**: Plain format includes `[project=test-project]`
- **T11**: JSON includes `"project_id": "test-project"`
- **T14**: JSON empty-container includes `"project_id"`
- **T15**: YAML includes `project_id: test-project`

### Task 12: Update `sb ps` test helper

**File:** `tests/sb-ps/unit/test_helper.bash`

No changes needed to `create_test_project` — it already writes `SB_PROJECT_ID=test-project`.

### Task 13: Update `sb ls` unit tests

**File:** `tests/sb-ls/unit/sandbox_ls.bats`

Update existing tests to expect the new `PROJECT ID` column:

- **T1**: Header now starts with `PROJECT ID`
- **T2**: Separator has dashes for PROJECT ID column
- **T3**: Data row starts with project ID value
- **T5**: Empty table header/separator includes PROJECT ID
- **T7**: Plain format includes `[project=test-project]`
- **T10**: JSON includes `"project_id": "test-project"`
- **T13**: YAML includes `project_id: test-project`

### Task 14: Update `sb ls` test helper

**File:** `tests/sb-ls/unit/test_helper.bash`

No changes needed — `create_test_project` already writes `SB_PROJECT_ID=test-project`.

### Task 15: Update CLAUDE.md

**File:** `CLAUDE.md`

Update the `sb ps` and `sb ls` documentation to reflect the new PROJECT ID column:
- `sb ps` table columns: Project ID, Sandbox ID, Status, Created, Container Name, Service, Image
- `sb ls` table columns: Project ID, Sandbox ID, Template ID, Image

### Task 16: Update README.md

**File:** `README.md`

Update the `sb ps` and `sb ls` subsections to reflect the new PROJECT ID column.

### Task 17: Run tests and verify

```bash
bats tests/sb-ps/unit/sandbox_ps.bats
bats tests/sb-ls/unit/sandbox_ls.bats
```

All tests must pass.
