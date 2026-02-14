# Implementation Summary: Add PROJECT ID Column to `sb ps` and `sb ls`

## Objective

Added a `PROJECT ID` column as the first column in `sb ps` and `sb ls` output, displaying the value of `SB_PROJECT_ID` from `sb-project.env`.

## Changes

### `bin/sb` — `sandbox_ps()`

- Read `SB_PROJECT_ID` from `sb-project.env` using `grep+sed` (consistent with existing env value reads in the function)
- **table**: Added `PROJECT ID` as first column with dynamic width calculation and 4-space gap
- **plain**: Added `[project=<id>]` tag after sandbox ID
- **json**: Added `"project_id"` as first field in each object
- **yaml**: Added `project_id` as first field in each list item

### `bin/sb` — `sandbox_ls()`

- Same approach as `sandbox_ps()` — read `SB_PROJECT_ID`, add as first column/field
- **table**: Added `PROJECT ID` as first column with dynamic width
- **plain**: Added `[project=<id>]` tag after sandbox ID
- **json**: Added `"project_id"` as first field in each object
- **yaml**: Added `project_id` as first field in each list item
- **minimal**: Unchanged (outputs sandbox IDs only)

### Tests

- **`tests/sb-ps/unit/sandbox_ps.bats`** (23 tests): Updated all tests to expect `PROJECT ID` column — header assertions, data row assertions, separator checks, JSON/YAML field checks
- **`tests/sb-ls/unit/sandbox_ls.bats`** (20 tests): Same updates
- Test helpers unchanged (`create_test_project` already writes `SB_PROJECT_ID=test-project`)

### Documentation

- **`CLAUDE.md`**: Updated `sb ps` and `sb ls` table column descriptions to include Project ID
- **`README.md`**: Updated `sb ps` and `sb ls` subsection column descriptions to include Project ID

## Test Results

- `sb ps`: 23/23 tests pass
- `sb ls`: 20/20 tests pass

## Example Output

### `sb ps` (table)

```
PROJECT ID    SANDBOX ID          STATUS                      CREATED           CONTAINER_NAME                   SERVICE    IMAGE
----------    ----------          ------                      -------           --------------                   -------    -----
test4         default             Up 19 hours (healthy)       19 hours ago      sandbox-test4-default            sandbox    sb-ubuntu-noble:latest
test4         test                Paused                      26 hours ago      sandbox-test4-test               sandbox    sb-ubuntu-noble-fw:latest
```

### `sb ls` (table)

```
PROJECT ID    SANDBOX ID    TEMPLATE ID                      IMAGE
----------    ----------    -----------                      -----
test4         default       sb-ubuntu-noble-fw-opensnitch    sb-ubuntu-noble-fw-opensnitch:latest
```
