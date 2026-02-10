# Detailed Plan: Task 3 - Add sb-templates list Sub-command

## Overview

Add a `list` (or `ls`) sub-command to `sb-templates` that displays all available sandbox templates and their associated Docker images.

## Problem Statement

Currently, there is no easy way for users to see which sandbox templates are available and what Docker images they use. Users must manually browse the `templates/sandboxes/` directory and inspect individual `sb-sandbox.env` files.

## Solution

Add a `list` sub-command to the `sb-templates` CLI that:
1. Scans the `templates/sandboxes/` directory for template directories
2. Reads each template's `artifacts/sb-sandbox.env` file
3. Extracts the `SB_SANDBOX_TEMPLATE_ID` and `SB_SANDBOX_IMAGE` values
4. Displays the information in a formatted table

## Expected Output

```
$ sb-templates list

Template ID          Docker Image
-----------          ------------
sb-ubuntu-noble      sb-ubuntu-noble:latest
sb-ubuntu-noble-fw   sb-ubuntu-noble-fw:latest
```

## Implementation Steps

### Step 1: Add the `list` command to parser_definition()

Add the `list` command to the existing `parser_definition()` function in `bin/sb-templates`:

```bash
parser_definition() {
	setup   REST help:usage abbr:true -- "Usage: $SCRIPT_NAME [<command>] [<command-options>]"

	msg -- '' "${SCRIPT_NAME}: Commands for managing sandbox templates" ''

	msg -- 'Options:'

	disp    :usage  -h --help
	disp    SCRIPT_VERSION    --version

	msg         -- '' 'Commands:'
	cmd init -- "Initializes templates environment configuration"
	cmd list -- "Lists available sandbox templates"       # <-- ADD THIS LINE
}
```

### Step 2: Add parser_definition_list() function

Add a new parser definition for the `list` command options:

```bash
parser_definition_list() {
	setup   REST help:usage abbr:true -- "Usage: $SCRIPT_NAME list [<options>]"
	msg -- '' 'Lists all available sandbox templates and their associated Docker images.'
	msg -- ''
	msg -- 'Options:'
	disp    :usage        -h    --help
}
```

### Step 3: Implement list_templates() function

Add a new function to list templates:

```bash
list_templates() {

	sb_install_root=$(readlink -f $SCRIPT_DIR/..)
	templates_dir=$sb_install_root/templates/sandboxes

	# Check templates directory exists
	if [ ! -d "$templates_dir" ]; then
		echo "$SCRIPT_NAME: Error: Templates directory '$templates_dir' does not exist"
		exit 1
	fi

	# Print header
	printf "\n%-25s %s\n" "Template ID" "Docker Image"
	printf "%-25s %s\n" "-----------" "------------"

	# Find and iterate over template directories
	found_templates=0
	for template_path in "$templates_dir"/*/; do
		# Skip if not a directory
		[ -d "$template_path" ] || continue

		template_name=$(basename "$template_path")
		env_file="$template_path/artifacts/sb-sandbox.env"

		# Check if sb-sandbox.env exists
		if [ -f "$env_file" ]; then
			# Source the env file to get variables
			SB_SANDBOX_TEMPLATE_ID=""
			SB_SANDBOX_IMAGE=""
			. "$env_file"

			# Use directory name if SB_SANDBOX_TEMPLATE_ID not set
			template_id="${SB_SANDBOX_TEMPLATE_ID:-$template_name}"
			image="${SB_SANDBOX_IMAGE:-<not specified>}"

			printf "%-25s %s\n" "$template_id" "$image"
			found_templates=1
		else
			# Template exists but no sb-sandbox.env
			printf "%-25s %s\n" "$template_name" "<NA- no sb-sandbox.env>"
			found_templates=1
		fi
	done

	if [ $found_templates -eq 0 ]; then
		echo ""
		echo "$SCRIPT_NAME: No templates found in '$templates_dir'"
	fi

	echo ""
}
```

### Step 4: Add command dispatch in main case statement

Update the case statement at the end of `bin/sb-templates` to handle the `list` command:

```bash
if [ $# -gt 0 ]; then
	cmd=$1
	shift
	case $cmd in
		init)
			cmd_parser="$(getoptions parser_definition_init)"
			eval "$cmd_parser"
			init_templates
			;;
		list)                                                    # <-- ADD THIS BLOCK
			cmd_parser="$(getoptions parser_definition_list)"
			eval "$cmd_parser"
			list_templates
			;;
		--) # no subcommand, arguments only
	esac
else
	usage
fi
```

## Files to Modify

| File | Action | Description |
|------|--------|-------------|
| `bin/sb-templates` | Edit | Add `list` command to parser, implement `list_templates()` function, add case dispatch |

## Detailed Code Changes

### Location 1: After line 31 (cmd init declaration)
Add:
```bash
cmd list -- "Lists available sandbox templates"
```

### Location 2: After line 52 (after error_init function)
Add the `parser_definition_list()` function.

### Location 3: After init_templates() function (after line 181)
Add the `list_templates()` function.

### Location 4: In the case statement (around line 193)
Add the `list)` case block.

## Testing

After implementation, verify by:

1. **Check help output shows list command:**
   ```bash
   sb-templates --help
   ```
   Expected: Should show `list` in the commands section

2. **Check list command help:**
   ```bash
   sb-templates list --help
   ```
   Expected: Should show usage information for list command

3. **Run list command:**
   ```bash
   sb-templates list
   ```
   Expected output:
   ```
   Template ID               Docker Image
   -----------               ------------
   sb-ubuntu-noble           sb-ubuntu-noble:latest
   sb-ubuntu-noble-fw        sb-ubuntu-noble-fw:latest
   ```

4. **Verify error handling (optional - remove templates dir temporarily):**
   The command should display an appropriate error if templates directory doesn't exist.

## Rationale

1. **Follows existing patterns**: The implementation mirrors the structure of the `init` command in `sb-templates` and other commands in `sb`
2. **Uses getoptions library**: Consistent with the project's CLI parsing approach
3. **Portable output format**: Simple column-based format that works in any terminal
4. **Handles edge cases**: Gracefully handles missing `sb-sandbox.env` files or empty templates directory
5. **Sources env file directly**: Rather than parsing with grep/sed, sourcing the env file is more reliable and handles quoted values correctly
