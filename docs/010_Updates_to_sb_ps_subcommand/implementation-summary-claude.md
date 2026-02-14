# Implementation Summary: Update `sb ls` Subcommand

**Plan:** `docs/dev/claude-plans/010_Updates_to_sb_ls_subcommand/plan-claude.md`
**Commit:** `e72c91d`
**Branch:** `main`

---

## Tasks Executed

### Task 1: Write BATS Unit Tests for All `sandbox_ls` Output Formats

Created test infrastructure and 20 BATS test cases covering all four output formats.

**Files created:**
- `tests/sb-ls/unit/test_helper.bash` — Shared helpers: `setup()`, `teardown()`, `source_sb_helpers()`, `create_test_sandbox()`, `create_test_project()`. Extracts `dir_search_tree_up_by_dirname()` and `sandbox_ls()` from `bin/sb` using `sed` for isolated testing.
- `tests/sb-ls/unit/run-tests.sh` — Test runner using project-local bats at `tests/tools/bats/bats-core/bin/bats`.
- `tests/sb-ls/unit/sandbox_ls.bats` — 20 test cases:
  - T1-T6: Table format (header, separator, data rows, multiple sandboxes, empty state, default format)
  - T7-T9: Plain format (single, multiple, empty)
  - T10-T12: JSON format (single, multiple, empty array)
  - T13-T15: YAML format (single, multiple, empty list)
  - T16-T18: Error handling (missing project, missing sandboxes dir, unknown format)
  - T19-T20: Edge cases (quoted env values, missing sb-sandbox.env)

**Deviation from plan:** `run-tests.sh` uses the project-local bats binary (`tests/tools/bats/bats-core/bin/bats`) instead of `command -v bats`, since bats is not installed globally on the host.

### Task 2: Run Tests to Verify They Fail

Ran `./tests/sb-ls/unit/run-tests.sh`. Result: 17 of 20 tests failed as expected. The 3 passing tests (T9, T16, T17) are error/edge cases that coincidentally pass with the old implementation.

### Task 3: Add `-o`/`--output` Option to `parser_definition_ls()`

Modified `parser_definition_ls()` in `bin/sb` (line 183):
- Added `output_format` param with `-o`/`--output` flags
- Fixed usage string from `"Usage: $SCRIPT_NAME compose [<sandbox>] [<options>]"` to `"Usage: $SCRIPT_NAME ls [<options>]"`
- Escaped quotes in `--project-path` description (`".sb"` to `\".sb\"`)

### Task 4: Update `sandbox_ls()` to Support All Four Output Formats

Rewrote `sandbox_ls()` in `bin/sb` (line 950). Changes:
- Added `ls_output_format` local variable defaulting to `table` from `$output_format`
- Replaced `find -printf '%f\n'` with a data collection loop that reads `SB_SANDBOX_TEMPLATE_ID` and `SB_SANDBOX_IMAGE` from each sandbox's `sb-sandbox.env` using `grep`+`sed` (avoids `source` for safety)
- Added `case` statement with four output formats: `table`, `plain`, `json`, `yaml`
- Added error case for unknown formats (exits with status 1)
- Removed stale `$sync_file_basename` references from error messages (copy-paste artifact from original code)

### Task 5: Run Tests to Verify They Pass

Ran `./tests/sb-ls/unit/run-tests.sh`. Result: All 20 tests passed.

### Spec Compliance Review

Dispatched spec compliance reviewer subagent. Result: **COMPLIANT** — all requirements from `plan-overview.md` implemented correctly.

### Code Quality Review

Dispatched code quality reviewer subagent. Findings:
- **I-1 (Important):** Unquoted `$project_path` in `readlink -f` call — fixed by adding quotes.
- **I-2 (Acknowledged):** JSON output does not escape special characters — accepted as low risk since sandbox IDs follow a restricted regex pattern.
- **S-5 (Noted):** bats-assert and bats-support git submodules added but not yet used by tests — kept for future use.

### Task 6: Manual Verification and Commit

- Re-ran tests after quoting fix: all 20 passed
- Committed as `e72c91d`

---

## Files Changed

| File | Change |
|------|--------|
| `bin/sb` | Modified `parser_definition_ls()` and `sandbox_ls()` |
| `tests/sb-ls/unit/test_helper.bash` | New — test helpers |
| `tests/sb-ls/unit/run-tests.sh` | New — test runner |
| `tests/sb-ls/unit/sandbox_ls.bats` | New — 20 BATS tests |
| `.gitmodules` | New — bats submodule references |
| `tests/tools/bats/bats-core` | New — git submodule |
| `tests/tools/bats/test_helper/bats-assert` | New — git submodule |
| `tests/tools/bats/test_helper/bats-support` | New — git submodule |
| `docs/dev/claude-plans/010_Updates_to_sb_ls_subcommand/plan-claude.md` | New — implementation plan |
| `docs/dev/claude-plans/010_Updates_to_sb_ls_subcommand/plan-overview.md` | New — high-level plan |
| `docs/dev/claude-plans/010_Updates_to_sb_ls_subcommand/prompts.md` | New — Claude prompts |
