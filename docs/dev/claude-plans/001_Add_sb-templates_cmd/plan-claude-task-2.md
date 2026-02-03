# Task 2: Update bin/sb-templates 'init' sub-command to populate image user password

## Overview

Update the `init` sub-command of `bin/sb-templates` to prompt for an image user password in addition to the existing root password prompt. The user password hash will be stored in `SB_TEMPLATES_IMAGE_USER_HASH` in `env/sb-templates.env`.

## Current State

The `bin/sb-templates` script already implements:
- Root password prompt with confirmation loop (lines 107-129)
- Hash generation using `openssl passwd -6 "$pass" | sed 's/\$/\$\$/g'`
- Writing `SB_TEMPLATES_IMAGE_SUHASH` to `env/sb-templates.env`

## Changes Required

### 1. Update help/description text in `parser_definition_init()`

**File:** `bin/sb-templates`
**Location:** Lines 34-43

Update the help message to mention both root and user passwords:

```bash
parser_definition_init() {
	setup   REST error:error_init help:usage abbr:true -- "Usage: $SCRIPT_NAME init [<options>]"
	msg -- '' 'Initializes the templates environment by generating password hashes for template images.'
	msg -- ''
	msg -- 'Creates env/sb-templates.env containing:'
	msg -- '  - SB_TEMPLATES_IMAGE_SUHASH (hashed root password)'
	msg -- '  - SB_TEMPLATES_IMAGE_USER_HASH (hashed user password)'
	msg -- ''
	msg -- 'Options:'
	flag    skip_confirm  -y    --skip-confirm    -- "Skip overwrite confirmation if env/sb-templates.env exists"
	disp    :usage        -h    --help
}
```

### 2. Add user password prompt loop in `init_templates()`

**File:** `bin/sb-templates`
**Location:** After the root password entry loop (after line 129), before hash generation (line 132)

Add a second password entry loop for the user password, following the same pattern as the root password:

```bash
# User password entry loop
while true; do

	read -sp "$SCRIPT_NAME: Enter user password for template images: " user_pass
	echo ""

	if [ -z "$user_pass" ]; then
		echo "$SCRIPT_NAME: Error: Password cannot be empty"
		continue
	fi

	echo ""
	read -sp "$SCRIPT_NAME: Re-enter password to confirm: " user_pass_confirm
	echo ""

	if [ "$user_pass" = "$user_pass_confirm" ]; then
		break
	else
		echo ""
		echo "$SCRIPT_NAME: Error: Passwords do not match, please try again"
		echo ""
	fi

done
```

### 3. Generate hash for user password

**File:** `bin/sb-templates`
**Location:** After root hash generation (line 132)

Add hash generation for the user password:

```bash
# Generate hashes
hash=$(openssl passwd -6 "$pass" | sed 's/\$/\$\$/g')
user_hash=$(openssl passwd -6 "$user_pass" | sed 's/\$/\$\$/g')
```

### 4. Update env file writing to include user hash

**File:** `bin/sb-templates`
**Location:** Lines 135-137

Update the heredoc to write both variables:

```bash
# Write env file
cat <<EOF > $templates_env_path
SB_TEMPLATES_IMAGE_SUHASH='$hash'
SB_TEMPLATES_IMAGE_USER_HASH='$user_hash'
EOF
```

## Implementation Steps

1. Open `bin/sb-templates` for editing
2. Update `parser_definition_init()` help text (lines 34-43)
3. Add user password entry loop after line 129
4. Add user hash generation after root hash generation (line 132)
5. Update the env file writing block to include both hashes (lines 135-137)

## Testing

After implementation, test by running:

```bash
./bin/sb-templates init
```

Expected behavior:
1. If `env/sb-templates.env` exists, prompt for overwrite confirmation (unless `-y` flag)
2. Prompt for root password (hidden input)
3. Prompt to re-enter root password for confirmation
4. Prompt for user password (hidden input)
5. Prompt to re-enter user password for confirmation
6. Generate both password hashes
7. Write both hashes to `env/sb-templates.env`
8. Output the path to the generated file

Verify the generated `env/sb-templates.env` contains:
```
SB_TEMPLATES_IMAGE_SUHASH='<hashed-root-password>'
SB_TEMPLATES_IMAGE_USER_HASH='<hashed-user-password>'
```

## Code Conventions

- Follow existing script conventions (prefix messages with `$SCRIPT_NAME:`)
- Use `read -sp` for hidden password input
- Use consistent variable naming (`user_pass`, `user_pass_confirm`, `user_hash`)
- Maintain empty line spacing consistent with existing code
