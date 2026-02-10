# Detailed Plan: Task 2 - Configure docker-compose.yaml for sb-ubuntu-noble-fw Template

## Overview

Configure the `sb-ubuntu-noble-fw` template to properly use its own Docker image (`sb-ubuntu-noble-fw:latest`) instead of inheriting the parent template's image name.

## Problem Statement

Currently, when a sandbox is created using the `sb-ubuntu-noble-fw` template:
1. The parent template's `copy.sh` copies `sb-sandbox.env` with `SB_SANDBOX_IMAGE=sb-ubuntu-noble:latest`
2. The child template's `copy.sh` uses a `sed` regex to replace the image name
3. This regex-based approach is fragile and could fail if the parent's format changes

## Solution

1. Create a dedicated `sb-sandbox.env` in the `sb-ubuntu-noble-fw` artifacts directory with the correct image name
2. Simplify the `copy.sh` script to unconditionally set the image name after copying artifacts

## Implementation Steps

### Step 1: Create sb-sandbox.env for sb-ubuntu-noble-fw

Create file: `templates/sandboxes/sb-ubuntu-noble-fw/artifacts/sb-sandbox.env`

Contents (mirrors parent but with different template ID and image):
```bash
SB_SANDBOX_TEMPLATE_ID="sb-ubuntu-noble-fw"
SB_SANDBOX_IMAGE=sb-ubuntu-noble-fw:latest
SB_SANDBOX_SHELL=/bin/bash
#SB_SANDBOX_MODULES=("example")
```

Key differences from parent (`sb-ubuntu-noble/artifacts/sb-sandbox.env`):
- `SB_SANDBOX_TEMPLATE_ID="sb-ubuntu-noble-fw"` (was `"sb-ubuntu-noble"`)
- `SB_SANDBOX_IMAGE=sb-ubuntu-noble-fw:latest` (was `sb-ubuntu-noble:latest`)

### Step 2: Update copy.sh to unconditionally set SB_SANDBOX_IMAGE

Modify file: `templates/sandboxes/sb-ubuntu-noble-fw/hooks/create/copy.sh`

Current line 47:
```bash
sed -i 's/SB_SANDBOX_IMAGE=sb-ubuntu-noble/SB_SANDBOX_IMAGE=sb-ubuntu-noble-fw/' $new_sandbox_path/sb-sandbox.env
```

Replace with:
```bash
sed -i 's/^SB_SANDBOX_IMAGE=.*/SB_SANDBOX_IMAGE=sb-ubuntu-noble-fw:latest/' $new_sandbox_path/sb-sandbox.env
```

This change:
- Uses `^SB_SANDBOX_IMAGE=.*` to match any existing `SB_SANDBOX_IMAGE` line regardless of its current value
- Sets the complete value including `:latest` tag explicitly
- Is more robust against changes in the parent template's image naming

## Files to Modify

| File | Action | Description |
|------|--------|-------------|
| `templates/sandboxes/sb-ubuntu-noble-fw/artifacts/sb-sandbox.env` | Create | New file with correct template ID and image |
| `templates/sandboxes/sb-ubuntu-noble-fw/hooks/create/copy.sh` | Edit | Update line 47 to use unconditional sed pattern |

## Testing

After implementation, verify by:

1. **Check artifacts file exists and has correct content:**
   ```bash
   cat templates/sandboxes/sb-ubuntu-noble-fw/artifacts/sb-sandbox.env
   ```
   Expected output:
   ```
   SB_SANDBOX_TEMPLATE_ID="sb-ubuntu-noble-fw"
   SB_SANDBOX_IMAGE=sb-ubuntu-noble-fw:latest
   SB_SANDBOX_SHELL=/bin/bash
   #SB_SANDBOX_MODULES=("example")
   ```

2. **Test sandbox creation** (if test project available):
   ```bash
   cd <test-project>
   sb new -t sb-ubuntu-noble-fw
   cat .sb/sandboxes/default/sb-sandbox.env | grep SB_SANDBOX_IMAGE
   ```
   Expected: `SB_SANDBOX_IMAGE=sb-ubuntu-noble-fw:latest`

## Rationale

The approach of having the child template's own `sb-sandbox.env` that gets copied over the parent's is cleaner because:

1. **Explicit configuration**: The template's image is defined in its own artifacts, making it self-documenting
2. **Robust sed pattern**: The `^SB_SANDBOX_IMAGE=.*` pattern works regardless of what value the parent set
3. **Follows existing pattern**: This mirrors how the parent's `copy.sh` works - it copies artifacts then adjusts paths
