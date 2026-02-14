# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI-Agents-Sandboxes is a Bash-based CLI tool for creating and managing isolated Docker development sandboxes. It provides template-based sandbox creation, a module system for extensibility, multi-level configuration management, file sync capabilities, and support for additional volumes at sandbox, project, and user levels.

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
sb ps [-o format]                      # Display status for all project sandboxes
sb ls [-o format]                      # List all sandboxes in the project
sb exec [sandbox-id] [opts] <cmd>      # Execute command in running sandbox
sb cp [sandbox-id] <src> <dest>        # Copy files between host and sandbox
sb run [sandbox-id] [opts] <cmd>       # Run one-off command in new container
sb logs [sandbox-id] [-f]              # Display container logs (-f to follow)
sb env [sandbox-id]                    # Print Docker Compose .env file
sb compose -c "<cmd>"                  # Run docker compose command
```

Common options: `-p/--project-path` to specify project, `-t/--template-id` for template selection, `-c/--sandbox-clone` to clone existing sandbox.

**`sb ps`** output formats (`-o`): `table` (default), `plain`, `json`, `yaml`. Table columns: Sandbox ID, Status, Created, Container Name, Service, Image.

**`sb ls`** output formats (`-o`): `table` (default), `minimal`, `plain`, `json`, `yaml`. Table columns: Sandbox ID, Template ID, Image.

**`sb exec`** passes all unrecognized options through to `docker compose exec` (e.g., `-T`, `-d`, `-u`, `-w`, `-e`). Uses `-v/--verbose` for verbose output. Resolves compose service from `SB_COMPOSE_SERVICE` in sandbox `sb-compose.env`.

**`sb cp`** uses `docker compose cp`. Prefix source or destination with the compose service name (e.g., `myservice:/path`). Supports `-a` (archive) and `-L` (follow symlinks).

**`sb run`** passes all unrecognized options through to `docker compose run` (e.g., `--rm`, `-T`, `-d`, `-u`, `-w`, `-e`, `-v`, `--entrypoint`). Uses `-v/--verbose` for verbose output.

### Project/User/Template Setup
```bash
sb-project init -i <project-id>  # Initialize project (creates .sb/ directory)
sb-user init                     # Initialize user configuration
sb-templates init                # Generate password hashes for template images
sb-templates list                # List available sandbox templates
```

### Building Docker Images
```bash
./templates/sandboxes/sb-ubuntu-noble/image/build.sh                # Build Ubuntu Noble image
./templates/sandboxes/sb-ubuntu-noble-fw/image/build.sh             # Build Ubuntu Noble with iptables firewall
./templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/build.sh  # Build Ubuntu Noble with OpenSnitch firewall
```

## Architecture

### Directory Structure
```
ai-agents-sandboxes/
├── bin/                          # CLI executables (sb, sb-project, sb-user, sb-templates, getoptions)
├── lib/                          # Shell libraries
│   ├── getoptions_lib            # Getoptions library wrapper
│   └── setup/getoptions/         # Getoptions setup (getoptions, gengetoptions, setup.sh)
├── env/                          # System-level configuration
│   ├── sb-system.env             # System defaults (default template, sandbox ID, modules)
│   └── sb-templates.env          # Template password hashes (SU_HASH, USER_HASH)
├── templates/
│   ├── sandboxes/                # Sandbox templates
│   │   ├── sb-ubuntu-noble/          # Base Ubuntu 24.04 template
│   │   ├── sb-ubuntu-noble-fw/       # Ubuntu Noble with iptables firewall
│   │   └── sb-ubuntu-noble-fw-opensnitch/  # Ubuntu Noble with OpenSnitch firewall
│   ├── project/project-init/     # Project initialization template
│   │   ├── sb-project.env        # Project env template
│   │   ├── sb-project-compose-include.yml
│   │   ├── project-sync.yml      # Project file sync spec
│   │   └── modules/              # Example project module
│   └── user/user-init/           # User initialization template
│       ├── user.env              # User env template
│       ├── user-secrets.env
│       ├── user-compose-include.yml
│       ├── user-sync.yml         # User file sync spec
│       └── modules/              # Example user module
├── modules/                      # System-wide modules
│   └── system-example/           # Example module template
├── tests/                        # Test suites (BATS)
│   ├── images/sb-ubuntu-noble-fw/  # Firewall image integration tests
│   ├── sb-ps/unit/                 # sb ps subcommand unit tests
│   ├── sb-ls/unit/                 # sb ls subcommand unit tests
│   └── sync/unit/                  # Sync functionality unit tests
└── docs/                         # Documentation & planning
    ├── setup.md                  # Setup steps
    └── dev/claude-plans/         # Implementation plans (001-006)
```

### Template Inheritance

Templates follow an inheritance pattern where child templates extend `sb-ubuntu-noble`:

```
sb-ubuntu-noble (base)
├── sb-ubuntu-noble-fw (extends base, adds iptables firewall)
└── sb-ubuntu-noble-fw-opensnitch (extends base, adds OpenSnitch firewall)
```

Child template hooks call parent hooks first, then overlay their own artifacts. For example, `copy-host.sh` in child templates runs the parent's `copy-host.sh` first, then copies the child's `artifacts-host/` files on top.

### Template Structure (`templates/sandboxes/<template-id>/`)
- `image/` - Docker image build
  - `docker/` - Dockerfile and container scripts (entrypoint.sh, SDK installers)
  - `build.sh` - Image build script (builds parent image first for child templates)
  - `run.sh` / `run_user.sh` - Manual run scripts for testing
- `artifacts-host/` - Files copied to sandbox host directory (docker-compose.yml, env files, modules/)
- `artifacts-sandbox/` - Files copied to sandbox container volumes
  - `sandbox/hooks/` - Container lifecycle hooks
  - `sandbox/modules/` - Module mount point
  - `sandbox/user/` / `sandbox/user_secrets/` - User data mount points
  - `sandbox/firewall/` - Firewall rules/logs (opensnitch template only)
- `hooks/create/` - Sandbox creation hooks: pre-copy.sh, copy-host.sh, post-copy.sh, post-container-create.sh, build.sh
- `hooks/sync/` - Configuration sync hooks (sync.sh)

### Configuration Hierarchy (lowest to highest priority)
1. **System** (`env/sb-system.env`) - Defaults installed with tool
2. **User** (`$SB_USER_ENV_ROOT/user.env` or `~/.config/sb/`) - User-wide settings
3. **Project** (`.sb/sb-project.env`) - Project-specific settings
4. **Sandbox** (`.sb/sandboxes/<id>/sb-sandbox.env`) - Per-sandbox settings

### Key Configuration Files

**Sandbox-Level** (`.sb/sandboxes/<id>/`):
- `sb-sandbox.env` - Template ID, image name, shell, modules, firewall root
- `sb-compose.env` - Docker Compose service, volume paths
- `sb-login.env` - User/group credentials
- `user.env` / `user-secrets.env` - Sandbox user environment
- `docker-compose.yml` - Docker Compose service definition
- `user-compose-include.yml` - Additional volumes (sandbox-level)
- `.env` - Auto-generated Docker Compose env (DO NOT MODIFY, use `sb sync`)
- `backup/dot-env/` - Backups of .env file from sync operations
- `logs/` - Sync operation logs

**Project-Level** (`.sb/`):
- `sb-project.env` - Project metadata, timezone, workspace root, module paths, prefix
- `sb-project-compose-include.yml` - Additional volumes (project-level)
- `project-sync.yml` - Project file sync spec (rsync-based)
- `modules/` - Project-specific modules
- `sandboxes/` - All project sandboxes

**User-Level** (`$SB_USER_ENV_ROOT/`):
- `user.env` - User defaults (template, sandbox ID, module search path)
- `user-secrets.env` - User credentials/secrets
- `user-compose-include.yml` - Additional volumes (user-level)
- `user-sync.yml` - User file sync spec (rsync-based)
- `modules/` - User-wide modules

### Module System
Modules extend sandbox functionality via hooks executed at different lifecycle points. Module structure:
```
<module-id>/
├── hooks/
│   ├── init/
│   │   └── init.sh        # Container initialization hook (runs once at container start)
│   └── shell-login/
│       └── login.sh       # Shell login hook (runs on each shell session)
├── artifacts/             # Files/resources for hooks
└── README.md
```

**Module Search Path** (priority order):
1. Sandbox: `.sb/sandboxes/<id>/modules/`
2. Sandbox config: `SB_MODULE_SEARCH_PATH` in sb-sandbox.env
3. Project config: `SB_PROJECT_MODULE_SEARCH_PATH` in sb-project.env
4. System: `<install-root>/modules/`
5. User: `SB_USER_MODULE_SEARCH_PATH` in user.env

Module IDs are specified in: `SB_SANDBOX_MODULES`, `SB_PROJECT_DEFAULT_MODULES`, `SB_USER_DEFAULT_MODULES`, `SB_SYSTEM_DEFAULT_MODULES`

### File Sync System

The file sync system uses YAML spec files to copy files from the host into sandbox containers during `sb new` and `sb sync`. Sync specs are processed at three levels (sandbox, project, user) and use rsync for staging followed by `docker compose cp`.

Sync spec format (YAML):
```yaml
sync:
  spec:
    - sandbox:
        path: "/target/path/in/container"
        include: ["pattern1", "pattern2"]  # optional
        exclude: ["pattern3"]              # optional
      host:
        path: "/source/path/on/host"
```

Paths support `__ENV__VARNAME` tokens resolved from the sandbox `.env` file.

### Volume Management

**Default Container Volumes**:
- `/workspace/<project-dir>` - Project workspace (bind mount)
- `/workspace/<project-dir>/.sb` - Shadow mount (hides .sb)
- `/sandbox/modules` - Installed modules
- `/sandbox/hooks` - Lifecycle hooks (init, shell-login)
- `/sandbox/user` - Non-sensitive user data persistence
- `/sandbox/user-secrets` - Sensitive user data persistence (.ssh, .nuget)
- `/sandbox/firewall` - Firewall rules and logs (opensnitch template only)

**Additional Volumes** (three levels):
1. Sandbox: `user-compose-include.yml` in sandbox directory
2. Project: `sb-project-compose-include.yml` in .sb/
3. User: `user-compose-include.yml` in $SB_USER_ENV_ROOT/

Docker Compose includes these via the `include:` directive.

### Container Configuration (sb-ubuntu-noble - base)
- Base: Ubuntu 24.04 Noble (`ubuntu:noble-20260113`)
- Memory limit: 8GB
- Process limit: 500 PIDs
- File descriptor limit: 65536
- Ephemeral /tmp: 1GB tmpfs
- IPC: private namespace
- Installed: git, curl, jq, vim, nano, less, wget, fzf, openssh-client, sudo, procps, net-tools, iputils-ping, dnsutils, netcat-openbsd, bash-completion, unzip, nftables, iptables, protobuf-compiler
- SDKs: gcloud SDK, dotnet SDK, gh CLI, Node.js/NVM, yq
- Python build deps: make, build-essential, libssl-dev, etc.
- Symlinks: `~/.ssh` -> `/sandbox/user-secrets/.ssh`, `~/.nuget` -> `/sandbox/user-secrets/.nuget`
- SUID bits removed from: mount, umount, chsh, chfn, gpasswd, newgrp, passwd

### Container Configuration (sb-ubuntu-noble-fw)
- Extends: sb-ubuntu-noble
- Additional packages: ipset, iproute2, aggregate
- Firewall: iptables-based with ipset for allowed domains
- Capabilities: NET_ADMIN, NET_RAW, SETUID, SETGID, DAC_OVERRIDE, CHOWN
- Allowed destinations: GitHub (API-resolved CIDRs), npm, Anthropic, Sentry, Statsig, localhost, host network, SSH
- Default policy: DROP all inbound/outbound except allowlisted

### Container Configuration (sb-ubuntu-noble-fw-opensnitch)
- Extends: sb-ubuntu-noble (directly, NOT sb-ubuntu-noble-fw)
- Firewall: OpenSnitch (application-level, domain-based) with nftables backend
- OpenSnitch daemon v1.7.2 intercepts outbound connections
- Custom Go TUI controller (`opensnitch-controller`) for interactive rule management (built from Go source at image build time; Go toolchain removed from final image)
- nftables rule restricts OpenSnitch gRPC port 50051 to root only
- Default action: deny (unknown connections blocked unless explicitly allowed)
- Capabilities: NET_ADMIN, NET_RAW, SETUID, SETGID, DAC_OVERRIDE, CHOWN
- Healthcheck: `pgrep -x opensnitchd` every 60s
- `FIREWALL_ENABLED` env var to toggle (default: true)
- Additional volume: `firewall` -> `/sandbox/firewall` (rules + logs)
- Pre-configured rules in `artifacts-sandbox/sandbox/firewall/rules/`:
  - 000: localhost, 001: DNS (Cloudflare 1.1.1.1/1.0.0.1), 002: RFC1918
  - 010: github.com, 011: githubusercontent, 020: npm, 021: Go modules
  - 025: ghcr.io, 030: Anthropic, 040: VS Code marketplace, 041: OpenVSX
  - 050: Google Gemini
  - Denies: Datadog telemetry
  - Misc allows: schemastore.org, Docker DNS (127.0.0.11)

### Container Startup Flow
1. Docker entrypoint (`/entrypoint.sh`) starts
2. Runs command: `/sandbox/hooks/init/init.sh`
3. Each template has its own `init.sh`. Init order by template:

   **sb-ubuntu-noble (base):**
   - `ssh-init.sh` - Setup SSH (symlink ~/.ssh to /sandbox/user-secrets/.ssh)
   - `nuget-init.sh` - Setup NuGet (symlink ~/.nuget to /sandbox/user-secrets/.nuget)
   - `dotnet-tools-init.sh` - Install dotnet tools
   - `nvm-init.sh` - Setup Node.js/NVM
   - `claude-init.sh` - Setup Claude AI
   - `modules-init.sh` - Initialize modules (executes each module's `hooks/init/init.sh`)

   **sb-ubuntu-noble-fw** (iptables firewall is baked into the image, no runtime firewall init):
   - `ssh-init.sh`, `nuget-init.sh`, `nvm-init.sh`, `claude-init.sh`, `modules-init.sh`

   **sb-ubuntu-noble-fw-opensnitch:**
   - `ssh-init.sh`, `nuget-init.sh`, `nvm-init.sh`, `claude-init.sh`, `modules-init.sh`
   - `firewall-init.sh` - Initialize OpenSnitch firewall (runs as root via sudo, last step)

4. Container runs `exec sleep infinity` to remain running

### Sandbox Creation Flow (`sb new`)
1. Resolve template (from command-line, project, user, or system default)
2. Build template image (`hooks/create/build.sh` - builds parent image first)
3. Create sandbox directory
4. Run pre-copy hook (`hooks/create/pre-copy.sh`)
5. Copy host artifacts (`hooks/create/copy-host.sh` - runs parent hook first, then overlays child artifacts)
6. Run post-copy hook (`hooks/create/post-copy.sh`)
7. Generate Docker Compose `.env` file (`sync_env`)
8. Create container (`docker compose up --no-start`)
9. Run post-container-create hook (`hooks/create/post-container-create.sh` - copies sandbox artifacts into container)
10. Sync external files (from sandbox/project/user sync specs)
11. Install modules (`sync_modules`)

## Testing

Uses [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System). Requires `bats` to be installed on the host.

```bash
# Sync unit tests
./tests/sync/unit/run-tests.sh                    # Run all sync tests
./tests/sync/unit/run-tests.sh <test-file.bats>   # Run specific test file

# sb ps unit tests
bats tests/sb-ps/unit/sandbox_ps.bats

# sb ls unit tests
bats tests/sb-ls/unit/sandbox_ls.bats

# Image tests (builds image, starts container, runs tests inside it)
./tests/images/sb-ubuntu-noble-fw/run-tests.sh             # Full run (builds image first)
./tests/images/sb-ubuntu-noble-fw/run-tests.sh --skip-build # Skip image build
```

## Code Conventions

- POSIX-compatible Bash scripts
- Uses getoptions library for CLI argument parsing
- ID regex pattern: `^[a-zA-Z](-|_|[a-zA-z]|[0-9])*`
- Template hook scripts use `SCRIPT_MSG_PREFIX` for structured logging: `[template=<id> operation=<op> hook=<hook>]`
- Module hook scripts use: `[module=<name> hook=<hook>]`
- Environment variable prefixes:
  - `SB_` - General system/configuration
  - `SB_PROJECT_*` - Project-level (ID, PREFIX, TZ, WORKSPACE_MAIN_ROOT, MODULE_SEARCH_PATH, DEFAULT_MODULES, DEFAULT_SANDBOX_ID, DEFAULT_TEMPLATE_ID)
  - `SB_SANDBOX_*` - Sandbox-level (TEMPLATE_ID, IMAGE, SHELL, MODULES_ROOT, HOOKS_ROOT, USER_ROOT, USER_SECRETS_ROOT, FIREWALL_ROOT, MODULES, WORKSPACE_MAIN_ROOT)
  - `SB_USER_*` - User-level (ENV_ROOT, DEFAULT_TEMPLATE_ID, DEFAULT_SANDBOX_ID, DEFAULT_MODULES, MODULE_SEARCH_PATH)
  - `SB_SYSTEM_*` - System defaults (DEFAULT_TEMPLATE_ID, DEFAULT_SANDBOX_ID, DEFAULT_MODULES)
  - `SB_COMPOSE_*` - Docker Compose related (SERVICE)
  - `SB_LOGIN_*` - Login/authentication (USER_ID, GROUP_ID, USER_NAME, GROUP_NAME, USER_HOME)
  - `SB_TEMPLATE_*` - Template-related
  - `SB_TEMPLATES_IMAGE_*` - Template image passwords (SU_HASH, USER_HASH)
  - `FIREWALL_ENABLED` - Toggle firewall (true/false, opensnitch template)
  - `SB_HOOK_DEBUG_ENABLED` - Enable verbose hook debug output (true/1)
  - `COMPOSE_PROJECT_NAME` - Auto-generated Docker Compose project name

## Initial Setup Flow
```bash
1. sb-user init                        # Create user config
2. sb-templates init                   # Generate password hashes for template images
3. export SB_USER_ENV_ROOT="<path>"    # Set in shell profile
4. Add bin/ to PATH
5. cd <project-dir>
6. sb-project init -i <project-id>     # Create project structure
7. sb new                              # Create default sandbox
8. sb up                               # Start sandbox
9. sb logs -f                          # Verify completion of sandbox initialization
10. sb shell                           # Start a shell session
```
