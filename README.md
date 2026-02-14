# AI-Agents-Sandboxes

A Bash-based CLI tool for creating and managing isolated Docker development sandboxes. Provides template-based sandbox creation, a module system for extensibility, multi-level configuration management, file sync capabilities, and support for additional volumes at sandbox, project, and user levels.

## Features

- **Template-based sandbox creation** - Pre-configured Docker images with different security profiles
- **Template inheritance** - Child templates extend parent templates, overlaying customizations
- **Module system** - Extensible hooks for container initialization and shell login
- **Multi-level configuration** - System, user, project, and sandbox-level settings with priority cascading
- **File sync** - YAML-spec-driven file synchronization from host to container using rsync
- **Additional volumes** - Mount extra volumes at sandbox, project, or user level
- **Firewall options** - iptables-based or OpenSnitch application-level firewall templates

## Available Templates

| Template | Description | Firewall |
|----------|-------------|----------|
| `sb-ubuntu-noble` | Base Ubuntu 24.04 template | None |
| `sb-ubuntu-noble-fw` | Ubuntu Noble with iptables firewall | iptables + ipset (IP-based allowlist) |
| `sb-ubuntu-noble-fw-opensnitch` | Ubuntu Noble with OpenSnitch firewall | OpenSnitch (application-level, domain-based) |

### Base Template (`sb-ubuntu-noble`)
- Ubuntu 24.04 Noble
- SDKs: gcloud, dotnet, gh CLI, Node.js/NVM, Python build deps
- Tools: git, curl, jq, vim, nano, fzf, yq, openssh-client
- Resource limits: 8GB memory, 500 PIDs, 65536 file descriptors
- Security: SUID bits removed, private IPC namespace, ephemeral /tmp

### iptables Firewall Template (`sb-ubuntu-noble-fw`)
- Extends base template
- iptables/ipset-based firewall initialized at container startup
- Resolves and allowlists GitHub CIDRs, npm, Anthropic, Sentry, Statsig
- Default policy: DROP all traffic except allowlisted destinations

### OpenSnitch Firewall Template (`sb-ubuntu-noble-fw-opensnitch`)
- Extends base template (directly, not the iptables template)
- OpenSnitch daemon v1.7.2 for application-level outbound connection interception
- Uses nftables as firewall backend
- Domain-based rules (not IP-based) - more reliable than iptables for dynamic IPs
- Custom Go TUI controller (`opensnitch-controller`) for interactive connection management
- Pre-configured rules for: localhost, DNS (Cloudflare), RFC1918, GitHub, npm, Go, ghcr.io, Anthropic, VS Code marketplace, OpenVSX, Gemini; denies Datadog telemetry
- gRPC port 50051 restricted to root via nftables
- Configurable via `FIREWALL_ENABLED` environment variable (default: true)
- Persistent rules and logs via `/sandbox/firewall` volume
- Healthcheck: `pgrep -x opensnitchd` every 60s

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Bash shell
- `openssl` (for password hash generation)
- `rsync` and `yq` (for file sync features)

### Setup

```bash
# 1. Clone the repository
git clone <repo-url>
cd ai-agents-sandboxes

# 2. Add bin/ to your PATH
export PATH="$PWD/bin:$PATH"

# 3. Initialize user configuration
sb-user init

# 4. Set the user env root (add to shell profile)
export SB_USER_ENV_ROOT="<path-shown-by-sb-user-init>"

# 5. Generate password hashes for template images
sb-templates init

# 6. Navigate to your project directory
cd /path/to/your/project

# 7. Initialize the project
sb-project init -i my-project

# 8. Create a sandbox (uses default template)
sb new

# 9. Start the sandbox
sb up

# 10. Wait for initialization to complete
sb logs -f

# 11. Open a shell
sb shell
```

### Using a Specific Template

```bash
# Create a sandbox with OpenSnitch firewall
sb new -t sb-ubuntu-noble-fw-opensnitch

# Create a sandbox with iptables firewall
sb new -t sb-ubuntu-noble-fw
```

## CLI Reference

### `sb` - Sandbox Management
```
sb new [sandbox-id] [-t template-id]   Create a new sandbox
sb up [sandbox-id]                     Start sandbox (create container if needed)
sb down [sandbox-id]                   Stop and remove Docker resources
sb start [sandbox-id]                  Start sandbox if not running
sb stop [sandbox-id]                   Gracefully stop sandbox
sb kill [sandbox-id]                   Forcefully stop sandbox
sb pause [sandbox-id]                  Pause running sandbox
sb unpause [sandbox-id]                Resume paused sandbox
sb shell [sandbox-id]                  Open interactive shell
sb sync [sandbox-id]                   Refresh config, rebuild image, recreate container
sb rm [sandbox-id]                     Delete sandbox
sb ps [-o format]                      Display status for all project sandboxes
sb ls [-o format]                      List all sandboxes in the project
sb exec [sandbox-id] [opts] <cmd>      Execute a command in a running sandbox
sb cp [sandbox-id] <src> <dest>        Copy files between host and sandbox
sb run [sandbox-id] [opts] <cmd>       Run a one-off command in a sandbox
sb logs [sandbox-id] [-f]              Display container logs
sb env [sandbox-id]                    Print Docker Compose .env file
sb compose -c "<cmd>"                  Run a docker compose command
```

#### `sb ps` - Sandbox Status

Displays status for all sandboxes in the project. Output formats (`-o`): `table` (default), `plain`, `json`, `yaml`.

Table columns: Sandbox ID, Status, Created, Container Name, Service, Image.

#### `sb ls` - List Sandboxes

Lists all sandboxes in the project. Output formats (`-o`): `table` (default), `minimal`, `plain`, `json`, `yaml`.

Table columns: Sandbox ID, Template ID, Image. The `minimal` format outputs sandbox IDs only (one per line).

#### `sb exec` - Execute Command

Executes a command in a running sandbox container. All unrecognized options are passed through to `docker compose exec` (e.g., `-T`, `-d`, `-u`, `-w`, `-e`).

```bash
sb exec ls -la /workspace              # Run in default sandbox
sb exec mysandbox whoami               # Run in specific sandbox
sb exec -T mysandbox cat /etc/hosts    # Disable pseudo-TTY allocation
```

Options: `-v/--verbose` for verbose output, `-p/--project-path` to specify project.

#### `sb cp` - Copy Files

Copies files/directories between the host and a sandbox container using `docker compose cp`. The source or destination must include the compose service name prefix (e.g., `myservice:/path/in/container`).

```bash
sb cp ./config.json myservice:/workspace/project/config.json   # Host to sandbox
sb cp myservice:/workspace/project/output ./output             # Sandbox to host
```

Options: `-a` (archive mode), `-L` (follow symlinks), `-p/--project-path`.

#### `sb run` - One-off Command

Runs a one-off command in a new container for the sandbox. Unlike `exec`, this starts a fresh container. All unrecognized options are passed through to `docker compose run` (e.g., `--rm`, `-T`, `-d`, `-u`, `-w`, `-e`, `-v`, `--entrypoint`).

```bash
sb run whoami                          # Run in default sandbox
sb run mysandbox ls -la /workspace     # Run in specific sandbox
sb run --rm whoami                     # Auto-remove container after run
```

Options: `-v/--verbose` for verbose output, `-p/--project-path` to specify project.

### `sb-project` - Project Management
```
sb-project init -i <project-id>        Initialize a new project
```

### `sb-user` - User Configuration
```
sb-user init                           Initialize user configuration
```

### `sb-templates` - Template Management
```
sb-templates init                      Generate password hashes for images
sb-templates list                      List available templates
```

## Architecture

### Configuration Hierarchy

Settings are resolved with the following priority (highest wins):

1. **Sandbox** (`.sb/sandboxes/<id>/sb-sandbox.env`)
2. **Project** (`.sb/sb-project.env`)
3. **User** (`$SB_USER_ENV_ROOT/user.env`)
4. **System** (`env/sb-system.env`)

### Template Inheritance

```
sb-ubuntu-noble (base)
├── sb-ubuntu-noble-fw (adds iptables firewall)
└── sb-ubuntu-noble-fw-opensnitch (adds OpenSnitch firewall)
```

Child templates call parent hooks first, then overlay their own artifacts.

### Container Volumes

| Volume | Mount Point | Purpose |
|--------|-------------|---------|
| `workspace_main` | `/workspace/<project>` | Project files (bind mount) |
| `workspace_sb_shadow` | `/workspace/<project>/.sb` | Hides .sb directory |
| `modules` | `/sandbox/modules` | Installed modules |
| `hooks` | `/sandbox/hooks` | Lifecycle hooks |
| `user` | `/sandbox/user` | Non-sensitive user data |
| `user_secrets` | `/sandbox/user-secrets` | Sensitive data (.ssh, .nuget) |
| `firewall` | `/sandbox/firewall` | Firewall rules/logs (opensnitch only) |

### Module System

Modules extend sandbox functionality via hooks:

```
<module-id>/
├── hooks/
│   ├── init/init.sh           # Runs once at container start
│   └── shell-login/login.sh   # Runs on each shell session
├── artifacts/                 # Module resources
└── README.md
```

Modules are resolved from multiple search paths (sandbox, project, system, user).

## Building Docker Images

```bash
# Build base image
./templates/sandboxes/sb-ubuntu-noble/image/build.sh

# Build iptables firewall image (builds base first)
./templates/sandboxes/sb-ubuntu-noble-fw/image/build.sh

# Build OpenSnitch firewall image (builds base first)
./templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/build.sh
```

## Testing

Uses [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System).

```bash
# Run sync unit tests
./tests/sync/unit/run-tests.sh

# Run sb ps unit tests
bats tests/sb-ps/unit/sandbox_ps.bats

# Run sb ls unit tests
bats tests/sb-ls/unit/sandbox_ls.bats

# Run firewall image integration tests
./tests/images/sb-ubuntu-noble-fw/run-tests.sh
./tests/images/sb-ubuntu-noble-fw/run-tests.sh --skip-build  # Skip image rebuild
```

## File Sync

The file sync system copies files from the host into sandbox containers using rsync + `docker compose cp`. Sync specs are defined in YAML files at three levels:

- **Sandbox**: `sb-sandbox-sync.yml`
- **Project**: `sb-project-sync.yml` (in `.sb/`)
- **User**: `user-sync.yml` (in `$SB_USER_ENV_ROOT/`)

```yaml
sync:
  spec:
    - sandbox:
        path: "/target/path/in/container"
        include: ["*.conf"]
        exclude: ["*.tmp"]
      host:
        path: "/source/path/on/host"
```

Paths support `__ENV__VARNAME` tokens that are resolved from the sandbox `.env` file.
