# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI-Agents-Sandboxes is a Bash-based CLI tool for creating and managing isolated Docker development sandboxes. It provides template-based sandbox creation, a module system for extensibility, multi-level configuration management, and support for additional volumes at sandbox, project, and user levels.

## Key Commands

### Sandbox Management (`sb`)
```bash
sb new [sandbox-id] [-t template-id]  # Create new sandbox
sb up [sandbox-id]                     # Start sandbox (create if needed)
sb down [sandbox-id]                   # Stop and remove Docker resources
sb start [sandbox-id]                  # Start sandbox if not running
sb stop [sandbox-id]                   # Gracefully stop sandbox
sb kill [sandbox-id]                   # Forcefully stop sandbox
sb pause [sandbox-id]                  # Pause running sandbox
sb unpause [sandbox-id]                # Resume paused sandbox
sb shell [sandbox-id]                  # Open interactive shell
sb sync [sandbox-id]                   # Refresh config, rebuild image, recreate container
sb rm [sandbox-id]                     # Delete sandbox
sb ps / sb ls                          # List sandboxes / show status
sb logs [sandbox-id]                   # Display container logs
sb compose -c "<cmd>"                  # Run docker compose command
```

Common options: `-p/--project-path` to specify project, `-t/--template-id` for template selection, `-c/--sandbox-clone` to clone existing sandbox.

### Project/User/Template Setup
```bash
sb-project init -i <project-id>  # Initialize project (creates .sb/ directory)
sb-user init                     # Initialize user configuration
sb-templates init                # Initialize configuration for Docker images required for the template sandboxes
```

### Building Docker Images
```bash
./templates/sandboxes/sb-ubuntu-noble/image/build.sh  # Build Ubuntu Noble image
```

## Architecture

### Directory Structure
```
ai-agents-sandboxes/
├── bin/                          # CLI executables (sb, sb-project, sb-user, sb-templates, getoptions)
├── lib/                          # Shell libraries (getoptions_lib, setup scripts)
├── env/                          # System-level configuration
│   ├── sb-system.env             # System defaults
│   └── sb-templates.env          # Template password hashes
├── templates/sandboxes/          # Sandbox templates
│   └── sb-ubuntu-noble/          # Default Ubuntu 24.04 template
│       ├── image/                # Docker image (Dockerfile, scripts)
│       ├── artifacts/            # Files copied to sandbox
│       └── hooks/                # Lifecycle hooks (create/, sync/)
├── modules/                      # System-wide modules
│   └── system-example/           # Example module template
├── docs/                         # Documentation & planning
└── test-projects/                # Example test project
```

### Configuration Hierarchy (lowest to highest priority)
1. **System** (`env/sb-system.env`) - Defaults installed with tool
2. **User** (`$SB_USER_ENV_ROOT/user.env` or `~/.config/sb/`) - User-wide settings
3. **Project** (`.sb/sb-project.env`) - Project-specific settings
4. **Sandbox** (`.sb/sandboxes/<id>/sb-sandbox.env`) - Per-sandbox settings

### Key Configuration Files

**Sandbox-Level** (`.sb/sandboxes/<id>/`):
- `sb-sandbox.env` - Template ID, image name, shell, modules
- `sb-compose.env` - Docker Compose service, volume paths
- `sb-login.env` - User/group credentials
- `user.env` / `user-secrets.env` - Sandbox user environment
- `docker-compose.yml` - Docker Compose service definition
- `user-compose-include.yml` - Additional volumes (sandbox-level)

**Project-Level** (`.sb/`):
- `sb-project.env` - Project metadata, timezone, workspace root, module paths
- `sb-project-compose-include.yml` - Additional volumes (project-level)
- `modules/` - Project-specific modules
- `sandboxes/` - All project sandboxes

**User-Level** (`$SB_USER_ENV_ROOT/`):
- `user.env` - User defaults (template, sandbox ID, module search path)
- `user-secrets.env` - User credentials/secrets
- `user-compose-include.yml` - Additional volumes (user-level)
- `modules/` - User-wide modules

### Template Structure (`templates/sandboxes/<template-id>/`)
- `image/docker/` - Dockerfile and container scripts (entrypoint.sh, SDK installers)
- `artifacts/` - Files copied to sandbox (docker-compose.yml, volumes/, modules/)
- `hooks/create/` - Lifecycle hooks: pre-copy.sh, copy.sh (required), post-copy.sh, build.sh (required)
- `hooks/sync/` - Configuration sync hooks (sync.sh)

### Module System
Modules extend sandbox functionality via `hooks/init.sh`. Module structure:
```
<module-id>/
├── hooks/init.sh    # Module initialization hook
├── artifacts/       # Files/resources for hooks
└── README.md
```

**Module Search Path** (priority order):
1. Sandbox: `.sb/sandboxes/<id>/modules/`
2. Sandbox config: `SB_MODULE_SEARCH_PATH` in sb-sandbox.env
3. Project config: `SB_PROJECT_MODULE_SEARCH_PATH` in sb-project.env
4. System: `<install-root>/modules/`
5. User: `SB_USER_MODULE_SEARCH_PATH` in user.env

Module IDs are specified in: `SB_MODULES`, `SB_PROJECT_DEFAULT_MODULES`, `SB_USER_DEFAULT_MODULES`, `SB_SYSTEM_DEFAULT_MODULES`

### Volume Management

**Default Container Volumes**:
- `/workspace/<project-dir>` - Project workspace (bind mount)
- `/workspace/<project-dir>/.sb` - Shadow mount (hides .sb)
- `/sandbox/modules` - Installed modules
- `/sandbox/init` - Init scripts
- `/sandbox/user` - Persistence of non-sensitive config for the sandbox user account 
- `/sandbox/user-secrets` - Persistence of sensitive config for the sandbox user account

**Additional Volumes** (three levels):
1. Sandbox: `user-compose-include.yml` in sandbox directory
2. Project: `sb-project-compose-include.yml` in .sb/
3. User: `user-compose-include.yml` in $SB_USER_ENV_ROOT/

Docker Compose includes these via the `include:` directive.

### Container Configuration (sb-ubuntu-noble)
- Base: Ubuntu 24.04 Noble
- Memory limit: 8GB
- Process limit: 500 PIDs
- File descriptor limit: 65536
- Ephemeral /tmp: 1GB tmpfs
- IPC: private namespace
- Installed: git, curl, jq, vim, gcloud SDK, dotnet SDK, gh CLI, Node.js/NVM

### Container Startup Flow
1. Docker entrypoint starts
2. `/sandbox/init/init.sh` runs:
   - `modules-init.sh` - Initialize modules
   - `nvm-init.sh` - Setup Node.js/NVM
   - `claude-init.sh` - Setup Claude AI
3. Container runs `sleep infinity` to remain runnig

## Code Conventions

- POSIX-compatible Bash scripts
- Uses getoptions library for CLI argument parsing
- ID regex pattern: `^[a-zA-Z](-|_|[a-zA-z]|[0-9])*`
- Environment variable prefixes:
  - `SB_` - General system/configuration
  - `SB_PROJECT_*` - Project-level
  - `SB_SANDBOX_*` - Sandbox-level
  - `SB_USER_*` - User-level
  - `SB_SYSTEM_*` - System defaults
  - `SB_COMPOSE_*` - Docker Compose related
  - `SB_LOGIN_*` - Login/authentication
  - `SB_TEMPLATE_*` - Template-related

## Initial Setup Flow
```bash
1. sb-user init                        # Create user config
2. sb-templates init                   # Generate config for sandbox templates
2. export SB_USER_ENV_ROOT="<path>"    # Set in shell profile
3  Add SB_USER_ENV_ROOT="<path>" to PATH env var
3. Add bin/ to PATH
5. cd <project-dir>
6. sb-project init -i <project-id>     # Create project structure
7. sb new                              # Create default sandbox
8. sb up                               # Start sandbox
9. sb logs                             # Verify completion of sandbox initialization
9. sb shell                            # Start a shell session 
10. 
```
