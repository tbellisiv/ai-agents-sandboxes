# Task 1: Create bin/sb-templates bash script

## Overview

Create `bin/sb-templates` with an `init` subcommand that generates `env/sb-templates.env` containing a hashed root password for template images.

## Implementation

### File to Create

**`bin/sb-templates`**

### Script Structure

```
1. Shebang and shellcheck directive
2. Script variables (SCRIPT_NAME, SCRIPT_DIR, SCRIPT_VERSION, LIB_DIR, GETOPTIONS_LIB_PATH)
3. Library existence check and source
4. parser_definition() - main command parser
5. parser_definition_init() - init subcommand parser
6. error_init() - error handler
7. init_templates() - init command implementation
8. Main execution block
```

### Key Components

#### 1. Script Header (same as bin/sb)

```bash
#!/bin/bash

# shellcheck disable=SC2034

SCRIPT_NAME=$(basename $0)
SCRIPT_DIR=$(dirname $0)
SCRIPT_VERSION=0.1

LIB_DIR=$SCRIPT_DIR/../lib
GETOPTIONS_LIB_PATH=$LIB_DIR/getoptions_lib

if [ ! -f "$GETOPTIONS_LIB_PATH" ]; then
    echo "$SCRIPT_NAME: Aborting- library '$GETOPTIONS_LIB_PATH' does not exist"
    exit -1
fi

. $GETOPTIONS_LIB_PATH
```

#### 2. Main Parser

```bash
parser_definition() {
    setup   REST help:usage abbr:true -- "Usage: $SCRIPT_NAME [<command>] [<command-options>]"
    msg -- '' "${SCRIPT_NAME}: Commands for managing sandbox templates" ''
    msg -- 'Options:'
    disp    :usage  -h --help
    disp    SCRIPT_VERSION    --version
    msg         -- '' 'Commands:'
    cmd init -- "Initializes templates environment configuration"
}
```

#### 3. Init Subcommand Parser

```bash
parser_definition_init() {
    setup   REST error:error_init help:usage abbr:true -- "Usage: $SCRIPT_NAME init [<options>]"
    msg -- '' 'Initializes the templates environment by generating a password hash for template images.'
    msg -- ''
    msg -- 'Creates env/sb-templates.env containing IMAGE_SUHASH (the hashed root password).'
    msg -- ''
    msg -- 'Options:'
    flag    skip_confirm  -y    --skip-confirm    -- "Skip overwrite confirmation if env/sb-templates.env exists"
    disp    :usage        -h    --help
}
```

#### 4. init_templates() Function Logic

1. **Setup paths**
   - `sb_install_root=$(readlink -f $SCRIPT_DIR/..)`
   - `templates_env_path=$sb_install_root/env/sb-templates.env`

2. **Verify openssl available**
   - `command -v openssl > /dev/null` or error exit

3. **Check env directory exists**

4. **File existence check with overwrite prompt**
   - If file exists and `-y` not provided:
     - Display: `"$SCRIPT_NAME: File '<path>' already exists."`
     - Loop: `read -r -p "$SCRIPT_NAME: Overwrite? [y(es) or n(o)]: " response`
     - On 'n': `echo "$SCRIPT_NAME: Aborting- user declined overwrite"` and `exit 0`

5. **Password entry loop**
   ```bash
   while true; do
       read -sp "$SCRIPT_NAME: Enter root password for template images: " pass
       echo ""
       # Validate not empty
       read -sp "$SCRIPT_NAME: Re-enter password to confirm: " pass_confirm
       echo ""
       # Break if match, else retry
   done
   ```

6. **Generate hash**
   ```bash
   hash=$(openssl passwd -6 "$pass" | sed 's/\$/\$\$/g')
   ```

7. **Write env file**
   ```bash
   cat <<EOF > $templates_env_path
   IMAGE_SUHASH=$hash
   EOF
   ```

8. **Output absolute path**
   ```bash
   echo "$(readlink -f $templates_env_path)"
   ```

#### 5. Main Execution Block

```bash
eval "$(getoptions parser_definition) exit 1"

if [ $# -gt 0 ]; then
    cmd=$1
    shift
    case $cmd in
        init)
            cmd_parser="$(getoptions parser_definition_init)"
            eval "$cmd_parser"
            init_templates
            ;;
        --)
    esac
else
    usage
fi
```

## Reference Files

- `bin/sb` - Primary reference for patterns, confirmation loop (lines 1264-1272), `-y` flag
- `bin/sb-project` - Init subcommand structure, file creation with here-doc
- `bin/get_passwd_hash.sh` - Password handling with `read -sp`, hash generation command

## Message Conventions

| Type | Format |
|------|--------|
| Normal | `"$SCRIPT_NAME: <message>"` |
| Error | `"$SCRIPT_NAME: Error: <details>"` |
| Aborting | `"$SCRIPT_NAME: Aborting- <reason>"` |
| Prompt | `"$SCRIPT_NAME: <prompt>: "` |

## Exit Codes

- **0**: Success or user declined overwrite
- **1**: Error (validation, file operation, etc.)
- **-1**: Fatal init error (library not found)

## Verification

1. Run `sb-templates --help` - should display usage with init command
2. Run `sb-templates init --help` - should display init usage
3. Run `sb-templates init` with no existing file - should prompt for password, create file
4. Run `sb-templates init` with existing file - should prompt for overwrite confirmation
5. Run `sb-templates init -y` with existing file - should skip confirmation
6. Verify `env/sb-templates.env` contains `IMAGE_SUHASH=<hash>`
7. Verify hash format: starts with `$$6$$` (escaped SHA-512 prefix)
