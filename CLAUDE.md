# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI-Agents-Sandboxes is a Bash-based CLI tool for creating and managing isolated Docker development sandboxes. It provides template-based sandbox creation, a module system for extensibility, and multi-level configuration management.

## Key Commands

### Sandbox Management (`sb`)
```bash
sb new [sandbox-id] [-t template-id]  # Create new sandbox
sb up [sandbox-id]                     # Start sandbox
sb down [sandbox-id]                   # Stop and remove Docker resources
sb shell [sandbox-id]                  # Open interactive shell
sb sync [sandbox-id]                   # Refresh config and rebuild image
sb rm [sandbox-id]                     # Delete sandbox
sb ps / sb ls                          # List sandboxes
sb compose -c "<cmd>"                  # Run docker compose command
```

### Project/User Setup
```bash
sb-project init    # Initialize project (creates .sb/ directory)
sb-user init       # Initialize user configuration
```

### Building Docker Images
```bash
./templates/sandboxes/sb-ubuntu-noble/image/build.sh  # Build Ubuntu Noble image
./scripts/docker-build-sandbox-local.sh               # Local image build helper
```

## Architecture

### Directory Structure
- `bin/` - CLI executables (`sb`, `sb-project`, `sb-user`)
- `lib/` - Shell libraries (getoptions for argument parsing)
- `templates/sandboxes/` - Sandbox templates (default: `sb-ubuntu-noble`)
- `modules/` - System-wide modules for extending sandboxes
- `env/` - System-level defaults (`sb-system.env`)

### Configuration Hierarchy (lowest to highest priority)
1. **System** (`env/sb-system.env`) - Defaults installed with tool
2. **User** (`~/.config/sb/` or `~/.sb/`) - User-wide settings
3. **Project** (`.sb/`) - Project-specific settings
4. **Sandbox** (`.sb/sandboxes/<id>/`) - Per-sandbox settings

### Key Configuration Files
- `sb-project.env` - Project metadata
- `sb-sandbox.env` - Sandbox settings (template, shell, etc.)
- `sb-compose.env` - Docker Compose variables
- `user.env` / `user-secrets.env` - User environment variables

### Template Structure (`templates/sandboxes/<template-id>/`)
- `image/docker/` - Dockerfile and container scripts
- `artifacts/` - Files copied to sandbox (docker-compose.yml, volumes)
- `hooks/create/` - Lifecycle hooks: pre-copy.sh, copy.sh, post-copy.sh, build.sh
- `hooks/sync/` - Configuration sync hooks

### Module System
Modules extend sandbox functionality via `hooks/init.sh`. Located in:
- System modules: `modules/`
- Sandbox modules: `.sb/sandboxes/<id>/sb-modules/`

### Container Configuration
- Memory limit: 8GB
- Process limit: 500
- File descriptor limit: 65536
- Ephemeral /tmp: 1GB
- IPC isolation enabled
- Workspace mounted at `/workspace/main`
- Project `.sb/` directory hidden via shadow mount

## Code Conventions

- POSIX-compatible Bash scripts
- Uses getoptions library for CLI argument parsing
- ID regex pattern: `^[a-zA-Z](-|_|[a-zA-z]|[0-9])*`
- Environment variable prefix: `SB_` for system variables
- Scripts use `shellcheck` disable directives where needed
