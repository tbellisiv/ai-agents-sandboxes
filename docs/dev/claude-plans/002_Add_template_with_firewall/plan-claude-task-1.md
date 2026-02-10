# Detailed Plan: Task 1 - Create sb-ubuntu-noble-fw Template

## Overview

Create a new sandbox template `sb-ubuntu-noble-fw` that extends the existing `sb-ubuntu-noble` template. This template will serve as the foundation for adding firewall capabilities in future tasks.

## Directory Structure to Create

```
templates/sandboxes/sb-ubuntu-noble-fw/
├── .gitignore
├── artifacts/
│   ├── .gitignore
│   ├── docker-compose.yml
│   └── README.md
├── hooks/
│   ├── create/
│   │   ├── pre-copy.sh
│   │   ├── copy.sh
│   │   ├── post-copy.sh
│   │   └── build.sh
│   └── sync/
│       └── sync.sh
└── image/
    ├── docker/
    │   └── Dockerfile
    ├── build.sh
    ├── run.sh
    └── run_user.sh
```

## Implementation Steps

### Step 1: Create Directory Structure

Create all required directories:
- `templates/sandboxes/sb-ubuntu-noble-fw/`
- `templates/sandboxes/sb-ubuntu-noble-fw/artifacts/`
- `templates/sandboxes/sb-ubuntu-noble-fw/image/`
- `templates/sandboxes/sb-ubuntu-noble-fw/image/docker/`
- `templates/sandboxes/sb-ubuntu-noble-fw/hooks/`
- `templates/sandboxes/sb-ubuntu-noble-fw/hooks/create/`
- `templates/sandboxes/sb-ubuntu-noble-fw/hooks/sync/`

### Step 2: Create image/docker/Dockerfile

Create a minimal Dockerfile that uses `sb-ubuntu-noble` as the base image:

```dockerfile
FROM sb-ubuntu-noble

# sb-ubuntu-noble-fw extends sb-ubuntu-noble with firewall capabilities
# Additional firewall-related packages and configuration will be added here
```

### Step 3: Create image/build.sh

Create a build script that:
1. First executes `templates/sandboxes/sb-ubuntu-noble/image/build.sh`
2. Checks for errors (exit if base image build fails)
3. Then builds the `sb-ubuntu-noble-fw` image

Key implementation details:
- Use `SCRIPT_DIR` to determine paths relative to the script location
- Set `IMAGE_TAG=sb-ubuntu-noble-fw`
- Set `PARENT_TEMPLATE_DIR` to reference `sb-ubuntu-noble`
- Execute parent's build.sh with error checking before building this image

### Step 4: Create image/run.sh

Create a run script for testing the image interactively:
- Set `IMAGE_TAG=sb-ubuntu-noble-fw`
- Run container with `docker run -it --rm`

### Step 5: Create image/run_user.sh

Create a run script for testing as non-root user:
- Set `IMAGE_TAG=sb-ubuntu-noble-fw`
- Run container with `-u 1000:1000` flag

### Step 6: Create hooks/create/pre-copy.sh

Create a script that:
1. Executes `templates/sandboxes/sb-ubuntu-noble/hooks/create/pre-copy.sh`
2. Checks for errors and exits if the parent script fails
3. Performs any additional pre-copy steps (initially none)

### Step 7: Create hooks/create/copy.sh

Create a script that:
1. Executes `templates/sandboxes/sb-ubuntu-noble/hooks/create/copy.sh` with the sandbox path argument
2. Checks for errors and exits if the parent script fails
3. Copies the `sb-ubuntu-noble-fw` artifacts (overwrites docker-compose.yml, adds README.md)

### Step 8: Create hooks/create/post-copy.sh

Create a script that:
1. Executes `templates/sandboxes/sb-ubuntu-noble/hooks/create/post-copy.sh` with the sandbox path argument
2. Checks for errors and exits if the parent script fails
3. Performs any additional post-copy steps (initially none)

### Step 9: Create hooks/create/build.sh

Create a script that:
1. Executes `templates/sandboxes/sb-ubuntu-noble/hooks/create/build.sh` with the sandbox path argument
2. Checks for errors and exits if the parent script fails
3. Builds the `sb-ubuntu-noble-fw` image using `image/build.sh`

### Step 10: Create hooks/sync/sync.sh

Create a script that:
1. Executes `templates/sandboxes/sb-ubuntu-noble/hooks/sync/sync.sh` with the sandbox path argument
2. Checks for errors and exits if the parent script fails
3. Performs any additional sync steps (initially none)

### Step 11: Create artifacts/docker-compose.yml

Copy the docker-compose.yml from `sb-ubuntu-noble/artifacts/` and modify:
- Keep the same structure and volume mounts
- The `SB_SANDBOX_IMAGE` variable will be set to `sb-ubuntu-noble-fw` in the sandbox's sb-sandbox.env

### Step 12: Create artifacts/README.md

Create a README documenting:
- Purpose of this template (firewall-enabled sandbox)
- That it extends sb-ubuntu-noble
- Future firewall capabilities

### Step 13: Create artifacts/.gitignore

Copy from `sb-ubuntu-noble/artifacts/.gitignore`:
```
.env
*secrets*
```

### Step 14: Create root .gitignore

Create a .gitignore at `templates/sandboxes/sb-ubuntu-noble-fw/.gitignore` if needed.

## Key Design Decisions

1. **Delegation Pattern**: All hooks delegate to the parent template first, then add their own logic. This ensures the child template inherits all parent behavior.

2. **Error Propagation**: Every script that calls a parent script must check the exit code and fail immediately if the parent fails.

3. **Minimal Artifacts**: The artifacts directory only contains files that differ from or extend the parent template (docker-compose.yml, README.md, .gitignore).

4. **Image Inheritance**: The Dockerfile uses `FROM sb-ubuntu-noble` to inherit all packages and configuration from the base image.

5. **Build Order**: The build.sh script ensures the parent image exists before building the child image.

## Script Template Pattern

All hook scripts should follow this pattern:

```bash
#!/bin/bash

SCRIPT_DIR=$(readlink -f $(dirname $0))
SCRIPT_NAME=$(basename $0)

TEMPLATE_DIR=$(readlink -f $SCRIPT_DIR/../..)
TEMPLATE_ID=$(basename $TEMPLATE_DIR)
TEMPLATE_OPERATION=$(basename $SCRIPT_DIR)
TEMPLATE_HOOK=$(basename $SCRIPT_NAME ".sh")

SCRIPT_MSG_PREFIX="[template=$TEMPLATE_ID operation=$TEMPLATE_OPERATION hook=$TEMPLATE_HOOK]"

# Parent template reference
PARENT_TEMPLATE_ID="sb-ubuntu-noble"
PARENT_TEMPLATE_DIR=$(readlink -f $TEMPLATE_DIR/../$PARENT_TEMPLATE_ID)

# Validate arguments
if [ -z "$1" ]; then
  echo "${SCRIPT_MSG_PREFIX}: Usage $SCRIPT_NAME <sandbox-path>"
  exit 1
fi

sandbox_path=$1

# Execute parent hook
parent_hook="$PARENT_TEMPLATE_DIR/hooks/$TEMPLATE_OPERATION/$SCRIPT_NAME"
if [ -f "$parent_hook" ]; then
  echo "${SCRIPT_MSG_PREFIX}: Executing parent hook"
  $parent_hook "$sandbox_path"
  if [ $? -ne 0 ]; then
    echo "${SCRIPT_MSG_PREFIX}: Error- parent hook failed"
    exit 1
  fi
fi

# Additional template-specific logic here

echo "${SCRIPT_MSG_PREFIX}: Complete"
```

## Testing

After implementation, verify by:
1. Running `./templates/sandboxes/sb-ubuntu-noble-fw/image/build.sh` - should build both images
2. Running `./templates/sandboxes/sb-ubuntu-noble-fw/image/run.sh` - should start container
3. Creating a test sandbox with `sb new -t sb-ubuntu-noble-fw` in a test project
