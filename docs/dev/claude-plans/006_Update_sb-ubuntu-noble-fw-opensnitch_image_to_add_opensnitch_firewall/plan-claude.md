# Add OpenSnitch Firewall to sb-ubuntu-noble-fw-opensnitch Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add OpenSnitch application-level firewall (daemon + interactive controller + rules) to the `sb-ubuntu-noble-fw-opensnitch` Docker image, closely mirroring the agentic-devcontainer reference implementation.

**Architecture:** The `sb-ubuntu-noble-fw-opensnitch` template extends `sb-ubuntu-noble` (base). The Dockerfile installs the OpenSnitch daemon (.deb), Go toolchain, and compiles the opensnitch-controller (Go gRPC TUI) from source. Firewall rules are stored as JSON files in `artifacts-sandbox/` and copied into a named Docker volume (`/sandbox/firewall`) at sandbox creation. The opensnitchd daemon starts during container init, reading rules from the volume.

**Tech Stack:** Docker, OpenSnitch v1.7.2, Go 1.25.5, gRPC/protobuf, nftables, Bash

**Reference:** `/home/tellis/dev/ai-tools/agent-sandboxes/devcontainers/git/agentic-devcontainer/.devcontainer/`

---

## Plan Summary: 11 Tasks

| Task | Description | Files |
|------|-------------|-------|
| 1 | Copy opensnitch-controller Go source | 5 new files |
| 2 | Create OpenSnitch daemon config files | 2 new files |
| 3 | Create firewall-init.sh startup script | 1 new file |
| 4 | **Rewrite Dockerfile** (install OpenSnitch, Go, build controller, sudoers) | 1 modified |
| 5 | Create 17 firewall rules in artifacts-sandbox | 18 new files |
| 6 | Update docker-compose.yml (caps, healthcheck, firewall volume) | 1 modified |
| 7 | Add `SB_SANDBOX_FIREWALL_ROOT` to sb-sandbox.env | 1 modified |
| 8 | Update init.sh to call firewall init | 1 modified |
| 9 | Fix post-container-create.sh to use `docker compose cp` | 1 modified |
| 10 | Update run.sh/run_user.sh with `--cap-add` flags | 2 modified |
| 11 | **Build & Validate** - test allowed/blocked traffic | Validation only |

**Totals:** 24 new files, 7 modified files

---

## Task 1: Copy opensnitch-controller Source Into Template

Copy the Go-based opensnitch-controller source files from the agentic-devcontainer reference into the template's image build context.

**Files:**
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/docker/opensnitch-controller/main.go`
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/docker/opensnitch-controller/ui.proto`
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/docker/opensnitch-controller/go.mod`
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/docker/opensnitch-controller/go.sum`
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/docker/opensnitch-controller/.gitignore`

**Step 1:** Copy all 5 files verbatim from `/home/tellis/dev/ai-tools/agent-sandboxes/devcontainers/git/agentic-devcontainer/.devcontainer/opensnitch-controller/` to `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/docker/opensnitch-controller/`.

No modifications needed - the source is identical.

**Step 2: Commit**

```bash
git add templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/docker/opensnitch-controller/
git commit -m "feat: add opensnitch-controller source to sb-ubuntu-noble-fw-opensnitch template"
```

---

## Task 2: Create OpenSnitch Config Files

Create the opensnitchd configuration files that will be baked into the Docker image at `/etc/opensnitchd/`.

**Files:**
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/docker/firewall/opensnitchd.default-config.json`
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/docker/firewall/opensnitchd.system-fw.json`

**Step 1:** Create `opensnitchd.default-config.json`

This is adapted from the agentic-devcontainer version. Key differences:
- `LogFile` path changed to `/sandbox/firewall/logs/opensnitchd.log` (uses sandbox volume)
- `Rules.Path` changed to `/sandbox/firewall/rules` (uses sandbox volume)

```json
{
    "Server": {
        "Address": "127.0.0.1:50051",
        "Authentication": {
            "Type": "simple",
            "TLSOptions": {
                "CACert": "",
                "ServerCert": "",
                "ClientCert": "",
                "ClientKey": "",
                "SkipVerify": false,
                "ClientAuthType": "no-client-cert"
            }
        },
        "LogFile": "/sandbox/firewall/logs/opensnitchd.log"
    },
    "DefaultAction": "deny",
    "DefaultDuration": "once",
    "InterceptUnknown": true,
    "ProcMonitorMethod": "proc",
    "LogLevel": 3,
    "LogUTC": true,
    "LogMicro": false,
    "Firewall": "nftables",
    "FwOptions": {
        "ConfigPath": "/etc/opensnitchd/system-fw.json",
        "MonitorInterval": "30s",
        "QueueBypass": true
    },
    "Rules": {
        "Path": "/sandbox/firewall/rules",
        "EnableChecksums": false
    },
    "Ebpf": {
        "EventsWorkers": 8,
        "QueueEventsSize": 0
    },
    "Stats": {
        "MaxEvents": 150,
        "MaxStats": 50,
        "Workers": 6
    },
    "Internal": {
        "GCPercent": 60,
        "FlushConnsOnStart": false
    }
}
```

**Step 2:** Copy `opensnitchd.system-fw.json` verbatim from `/home/tellis/dev/ai-tools/agent-sandboxes/devcontainers/git/agentic-devcontainer/.devcontainer/firewall/opensnitchd.system-fw.json`.

No modifications needed.

**Step 3: Commit**

```bash
git add templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/docker/firewall/
git commit -m "feat: add opensnitchd config files for sb-ubuntu-noble-fw-opensnitch"
```

---

## Task 3: Create firewall-init.sh Script

Create the firewall initialization script that starts the opensnitchd daemon. This is baked into the Docker image at `/usr/local/bin/firewall-init.sh` and called via sudo during container initialization.

**Files:**
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/docker/firewall-init.sh`

**Step 1:** Create `firewall-init.sh`

Adapted from the agentic-devcontainer's `scripts/firewall-init.sh`. Key differences:
- No `DEVCONTAINER` check (sandbox context, not devcontainer)
- Log paths use `/sandbox/firewall/logs/` instead of `/workspace/main/.devcontainer-stores/logs/`
- Rules at `/sandbox/firewall/rules/` (populated from container volume)

```bash
#!/bin/bash
# firewall-init.sh - Initialize OpenSnitch firewall in sandbox container
# Runs as root via sudo from sandbox init chain
# SECURITY: Log files are created by this script with root ownership

SCRIPT_NAME=$(basename "$0")

FIREWALL_DIR="/sandbox/firewall"
LOGS_DIR="$FIREWALL_DIR/logs"
RULES_DIR="$FIREWALL_DIR/rules"
FIREWALL_LOG="$LOGS_DIR/firewall-init.log"
CONFIG_FILE="/etc/opensnitchd/default-config.json"

# Ensure log directory exists and is secure
mkdir -p "$LOGS_DIR"
chown root:root "$LOGS_DIR"
chmod 755 "$LOGS_DIR"

# Create log files safely (prevent symlink attacks)
for logfile in "opensnitchd.log" "opensnitch-controller.log" "firewall-init.log"; do
    filepath="$LOGS_DIR/$logfile"
    [ -L "$filepath" ] && rm -f "$filepath"
    : > "$filepath"
    chown root:root "$filepath"
    chmod 644 "$filepath"
done

# Redirect output to log file
exec > >(tee "$FIREWALL_LOG") 2>&1

# Check if firewall is enabled
if [ "${FIREWALL_ENABLED:-true}" != "true" ]; then
    echo "[$SCRIPT_NAME] FIREWALL_ENABLED=$FIREWALL_ENABLED - skipping firewall initialization"
    exit 0
fi

echo "[$SCRIPT_NAME] Initializing OpenSnitch firewall..."

# Protect gRPC port 50051 - only root can connect to the controller TUI
# Prevents non-root users from manipulating firewall rules via gRPC
echo "[$SCRIPT_NAME] Adding nftables rule to restrict port 50051 to root..."
nft add table inet opensnitch-protect 2>/dev/null || true
nft flush table inet opensnitch-protect 2>/dev/null || true
nft add chain inet opensnitch-protect output '{ type filter hook output priority 0; policy accept; }'
nft add rule inet opensnitch-protect output tcp dport 50051 meta skuid != 0 drop
echo "[$SCRIPT_NAME] Port 50051 restricted to root-only access"

# Rules directory - set ownership and permissions
if [ -d "$RULES_DIR" ]; then
    chown -R root:root "$RULES_DIR"
    chmod 755 "$RULES_DIR"
    chmod 644 "$RULES_DIR"/*.json 2>/dev/null || true
    echo "[$SCRIPT_NAME] Rules directory: $RULES_DIR (root-owned)"
    echo "[$SCRIPT_NAME] Rules:"
    ls -la "$RULES_DIR"/ 2>/dev/null || echo "  (no rules found)"
else
    echo "[$SCRIPT_NAME] WARNING: Rules directory not found: $RULES_DIR"
    echo "[$SCRIPT_NAME] Container will start WITHOUT firewall rules"
fi

# Start the OpenSnitch daemon
echo "[$SCRIPT_NAME] Starting opensnitchd..."
/usr/bin/opensnitchd -config-file "$CONFIG_FILE" -rules-path "$RULES_DIR" > "$LOGS_DIR/opensnitchd.log" 2>&1 &
DAEMON_PID=$!

# Wait for daemon to be ready
sleep 3
if ! kill -0 $DAEMON_PID 2>/dev/null; then
    echo "[$SCRIPT_NAME] WARNING: opensnitchd failed to start"
    echo "[$SCRIPT_NAME] Check logs: cat $LOGS_DIR/opensnitchd.log"
    echo "[$SCRIPT_NAME] Container will continue WITHOUT firewall protection"
    cat "$LOGS_DIR/opensnitchd.log" 2>/dev/null | head -20 || true
    exit 0 # Don't block container startup
fi
echo "[$SCRIPT_NAME] opensnitchd started (PID: $DAEMON_PID)"

echo "[$SCRIPT_NAME] OpenSnitch firewall initialized successfully"
echo ""
echo "[$SCRIPT_NAME] Usage:"
echo "  - Run 'sudo opensnitch-controller' in a terminal to interactively manage connections"
echo "  - Rules are in $RULES_DIR/"
echo "  - View logs: tail -f $LOGS_DIR/opensnitchd.log"
```

**Step 2: Commit**

```bash
git add templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/docker/firewall-init.sh
git commit -m "feat: add firewall-init.sh for OpenSnitch daemon startup"
```

---

## Task 4: Update Dockerfile

Replace the minimal `FROM sb-ubuntu-noble` Dockerfile with one that installs OpenSnitch daemon, Go, compiles the opensnitch-controller, and configures sudoers/firewall scripts.

**Files:**
- Modify: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/docker/Dockerfile`

**Step 1:** Rewrite the Dockerfile

The new Dockerfile closely mirrors the agentic-devcontainer's `devcontainer.Dockerfile`, adapted for the sandbox architecture:
- Base image is `sb-ubuntu-noble` (not `node:24-trixie-slim`)
- No pnpm/npm/node setup (handled by base image's nvm-init.sh)
- No workspace/config directory creation (handled by base image)
- Uses sandbox user from base image (not hardcoded `node`)
- Config files go to `/etc/opensnitchd/`
- Sudoers references sandbox user from `/sandbox/build/sb-login.env`

```dockerfile
FROM sb-ubuntu-noble

# sb-ubuntu-noble-fw-opensnitch extends sb-ubuntu-noble with OpenSnitch firewall

ARG OPENSNITCH_VERSION=1.7.2
ARG GO_VERSION=1.25.5

### FIREWALL ###

#-- OpenSnitch daemon (application-level firewall)
RUN ARCH=$(dpkg --print-architecture) && \
    wget -q "https://github.com/evilsocket/opensnitch/releases/download/v${OPENSNITCH_VERSION}/opensnitch_${OPENSNITCH_VERSION}-1_${ARCH}.deb" && \
    apt-get update && \
    apt-get install -y "./opensnitch_${OPENSNITCH_VERSION}-1_${ARCH}.deb" && \
    rm -f "opensnitch_${OPENSNITCH_VERSION}-1_${ARCH}.deb" && \
    systemctl disable opensnitch 2>/dev/null || true && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

#-- Go (for building opensnitch-controller)
RUN ARCH=$(dpkg --print-architecture) && \
    wget -q "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" && \
    tar -C /usr/local -xzf "go${GO_VERSION}.linux-${ARCH}.tar.gz" && \
    rm -f "go${GO_VERSION}.linux-${ARCH}.tar.gz"
ENV PATH=$PATH:/usr/local/go/bin

#-- OpenSnitch Controller (built from source - interactive TUI for managing firewall rules)
COPY opensnitch-controller /tmp/opensnitch-controller
RUN cd /tmp/opensnitch-controller && \
    go install google.golang.org/protobuf/cmd/protoc-gen-go@latest && \
    go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest && \
    export PATH=$PATH:$(go env GOPATH)/bin && \
    mkdir -p pb && \
    protoc --go_out=pb --go_opt=paths=source_relative \
           --go-grpc_out=pb --go-grpc_opt=paths=source_relative \
           ui.proto && \
    CGO_ENABLED=0 go build -ldflags="-s -w" -o /usr/local/sbin/opensnitch-controller . && \
    chown root:root /usr/local/sbin/opensnitch-controller && \
    chmod 700 /usr/local/sbin/opensnitch-controller && \
    rm -rf /tmp/opensnitch-controller && \
    rm -rf $(go env GOPATH) $(go env GOCACHE)

#-- Remove Go toolchain (only needed for build, saves ~500MB in final image)
RUN rm -rf /usr/local/go
ENV PATH=${PATH%:/usr/local/go/bin}

#-- OpenSnitch config files
COPY firewall/opensnitchd.default-config.json /etc/opensnitchd/default-config.json
COPY firewall/opensnitchd.system-fw.json /etc/opensnitchd/system-fw.json

#-- Firewall initialization script
COPY firewall-init.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/firewall-init.sh

#-- Sudoers: allow sandbox user to run firewall scripts without password
RUN . /sandbox/build/sb-login.env && \
    echo "Defaults env_keep += \"FIREWALL_ENABLED\"" > /etc/sudoers.d/env-keep-firewall && \
    chmod 0440 /etc/sudoers.d/env-keep-firewall && \
    echo "$SB_LOGIN_USER_NAME ALL=(root) NOPASSWD: /usr/local/bin/firewall-init.sh" > /etc/sudoers.d/firewall && \
    chmod 0440 /etc/sudoers.d/firewall && \
    printf "Defaults!/usr/local/sbin/opensnitch-controller rootpw\n$SB_LOGIN_USER_NAME ALL=(root) /usr/local/sbin/opensnitch-controller\n" > /etc/sudoers.d/opensnitch-controller && \
    chmod 0440 /etc/sudoers.d/opensnitch-controller

#-- Create opensnitch-controller wrapper (prompts for root password or uses sudo)
RUN . /sandbox/build/sb-login.env && \
    cat <<'WRAPPER_EOF' > /usr/local/bin/opensnitch-controller
#!/bin/bash
ADDR="127.0.0.1:50051"
if [ "$(id -u)" -eq 0 ]; then
    exec /usr/local/sbin/opensnitch-controller --addr "$ADDR" "$@"
fi
exec sudo /usr/local/sbin/opensnitch-controller --addr "$ADDR" "$@"
WRAPPER_EOF
RUN chmod +x /usr/local/bin/opensnitch-controller

#-- Create firewall directory structure in image (volume will overlay at runtime)
RUN mkdir -p /sandbox/firewall/rules /sandbox/firewall/logs && \
    . /sandbox/build/sb-login.env && \
    chown -R ${SB_LOGIN_USER_ID}:${SB_LOGIN_GROUP_ID} /sandbox/firewall
```

**Design Decisions:**
- Go toolchain is removed after building the controller to reduce image size
- The `opensnitch-controller` binary is owned by root with mode 700 (only root can execute the real binary)
- A wrapper script at `/usr/local/bin/opensnitch-controller` uses sudo to elevate (requires root password)
- `Defaults!/usr/local/sbin/opensnitch-controller rootpw` means running the controller requires the root password (set via `SU_HASH` at build time), providing a security gate for interactive firewall management
- `FIREWALL_ENABLED` env var is passed through sudoers via `env_keep`
- Config files are baked into the image; rules come from the container volume

**Step 2: Verify Dockerfile builds**

```bash
./templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/build.sh
```

Expected: Image builds successfully. This will take several minutes (Go compilation, OpenSnitch download).

**Step 3: Commit**

```bash
git add templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/docker/Dockerfile
git commit -m "feat: update Dockerfile to install OpenSnitch daemon and build controller"
```

---

## Task 5: Create Firewall Rules in artifacts-sandbox

Create all OpenSnitch JSON rule files that will be copied into the container's `/sandbox/firewall/rules/` volume.

**Files (17 rule files + 1 README):**
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-sandbox/sandbox/firewall/rules/000-allow-localhost.json`
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-sandbox/sandbox/firewall/rules/001-allow-dns.json`
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-sandbox/sandbox/firewall/rules/002-allow-rfc1918.json`
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-sandbox/sandbox/firewall/rules/010-allow-github.json`
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-sandbox/sandbox/firewall/rules/011-allow-githubusercontent.json`
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-sandbox/sandbox/firewall/rules/020-allow-npm.json`
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-sandbox/sandbox/firewall/rules/021-allow-go.json`
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-sandbox/sandbox/firewall/rules/025-allow-ghcr.json`
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-sandbox/sandbox/firewall/rules/030-allow-anthropic.json`
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-sandbox/sandbox/firewall/rules/040-allow-vscode-marketplace.json`
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-sandbox/sandbox/firewall/rules/041-allow-openvsx.json`
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-sandbox/sandbox/firewall/rules/050-allow-google-gemini.json`
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-sandbox/sandbox/firewall/rules/allow-127.0.0.11.json`
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-sandbox/sandbox/firewall/rules/allow-json.schemastore.org.json`
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-sandbox/sandbox/firewall/rules/allow-www.schemastore.org.json`
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-sandbox/sandbox/firewall/rules/deny-http-intake.logs.datadoghq.com.json`
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-sandbox/sandbox/firewall/rules/deny-http-intake.logs.us5.datadoghq.com.json`
- Create: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-sandbox/sandbox/firewall/logs/README.md`

**Step 1:** Copy all 17 rule JSON files verbatim from `/home/tellis/dev/ai-tools/agent-sandboxes/devcontainers/git/agentic-devcontainer/.devcontainer/firewall/rules/` to `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-sandbox/sandbox/firewall/rules/`.

No modifications needed - the rules are identical.

**Step 2:** Create `artifacts-sandbox/sandbox/firewall/logs/README.md` as an empty placeholder (ensures the logs directory is created).

**Step 3: Commit**

```bash
git add templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-sandbox/sandbox/firewall/
git commit -m "feat: add OpenSnitch firewall rules and logs directory"
```

---

## Task 6: Update docker-compose.yml

Update the sandbox's docker-compose.yml to enable Linux capabilities, add a healthcheck for opensnitchd, add the `FIREWALL_ENABLED` environment variable, and add a named volume for firewall data.

**Files:**
- Modify: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-host/docker-compose.yml`

**Step 1:** Apply these changes to the docker-compose.yml:

1. **Uncomment and enable `cap_drop` and `cap_add`** (currently commented out):
```yaml
        cap_drop:
            - ALL
        cap_add:
            # firewall:
            - NET_ADMIN
            - NET_RAW
            # sudo/root:
            - SETUID
            - SETGID
            - DAC_OVERRIDE
            - CHOWN
```

2. **Add healthcheck** after the `ulimits` block:
```yaml
        healthcheck:
            test: ['CMD', 'pgrep', '-x', 'opensnitchd']
            interval: 60s
            timeout: 10s
            retries: 3
            start_period: 30s
```

3. **Add `FIREWALL_ENABLED`** to the `environment` list:
```yaml
            - FIREWALL_ENABLED=true
```

4. **Add `firewall` volume** to the `volumes` section of the service:
```yaml
            #firewall config, rules, and logs
            - firewall:${SB_SANDBOX_FIREWALL_ROOT}
```

5. **Add `firewall` named volume** to the top-level `volumes` section:
```yaml
    firewall:
```

**Step 2: Commit**

```bash
git add templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-host/docker-compose.yml
git commit -m "feat: update docker-compose.yml with caps, healthcheck, and firewall volume"
```

---

## Task 7: Update sb-sandbox.env

Add the `SB_SANDBOX_FIREWALL_ROOT` variable to the sandbox environment file so the docker-compose.yml can reference it.

**Files:**
- Modify: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-host/sb-sandbox.env`

**Step 1:** Add this line to the end of `sb-sandbox.env`:

```bash
SB_SANDBOX_FIREWALL_ROOT=/sandbox/firewall
```

**Step 2: Commit**

```bash
git add templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-host/sb-sandbox.env
git commit -m "feat: add SB_SANDBOX_FIREWALL_ROOT to sb-sandbox.env"
```

---

## Task 8: Update init.sh to Call Firewall Init

Update the sandbox container's `init.sh` to include firewall initialization as part of the startup chain.

**Files:**
- Modify: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-sandbox/sandbox/hooks/init/init.sh`

**Step 1:** Add firewall init step to init.sh

The firewall should initialize early in the chain (before modules, after SSH/NuGet/NVM/Claude) so that module network activity is governed by the firewall. Add this block after the Claude init and before the modules init:

```bash
# ----- Init: Firewall (OpenSnitch) ------
sudo /usr/local/bin/firewall-init.sh
firewall_init=$?
```

Also add the corresponding status check in the error reporting section:

```bash
if [ $firewall_init -ne 0 ]; then
  init_status=1
  echo "$SCRIPT_NAME: Warning- Firewall initialization failed"
  echo ""
fi
```

**Step 2: Commit**

```bash
git add templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-sandbox/sandbox/hooks/init/init.sh
git commit -m "feat: add firewall init step to container startup chain"
```

---

## Task 9: Fix post-container-create.sh to Copy Artifacts Into Container

The `post-container-create.sh` hook currently has the overlay copy commented out. It needs to use `docker compose cp` (not host `cp`) to copy this template's artifacts-sandbox into the running container, overlaying the parent template's artifacts.

**Files:**
- Modify: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/hooks/create/post-container-create.sh`

**Step 1:** Replace the commented-out section:

```bash
#There are no artifacts to overlay currently
#cp -r -f $template_artifacts_path/* $new_sandbox_path
```

With a proper `docker compose cp` implementation (matching the parent template's pattern):

```bash
# Copy this template's sandbox artifacts into the running container (overlay parent's artifacts)
new_sandbox_compose_env_path=$new_sandbox_path/sb-compose.env
if [ ! -f "$new_sandbox_compose_env_path" ]; then
  echo "${SCRIPT_MSG_PREFIX}: Error: Sandbox env file '$new_sandbox_compose_env_path' does not exist"
  exit 1
fi

source $new_sandbox_compose_env_path
if [ -z "${SB_COMPOSE_SERVICE}" ]; then
  echo "${SCRIPT_MSG_PREFIX}: Error: Variable 'SB_COMPOSE_SERVICE' is not defined in file '$new_sandbox_compose_env_path'"
  exit 1
fi

compose_file_path=$new_sandbox_path/docker-compose.yml
if [ ! -f "${compose_file_path}" ]; then
  echo "${SCRIPT_MSG_PREFIX}: Error: Docker compose file '$compose_file_path' does not exist"
  exit 1
fi

echo "${SCRIPT_MSG_PREFIX}: Copying sandbox container artifacts: ${template_artifacts_path}/* --> ${SB_COMPOSE_SERVICE}:/"
docker compose -f $compose_file_path cp $template_artifacts_path/. ${SB_COMPOSE_SERVICE}:/
if [ $? -ne 0 ]; then
  echo "${SCRIPT_MSG_PREFIX}: Error: Docker compose file copy failed"
  exit 1
fi
```

**Step 2: Commit**

```bash
git add templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/hooks/create/post-container-create.sh
git commit -m "fix: implement docker compose cp in post-container-create.sh for artifact overlay"
```

---

## Task 10: Update run.sh and run_user.sh for Testing

The `run.sh` and `run_user.sh` scripts need `--cap-add` flags so the firewall can be initialized when testing the image manually.

**Files:**
- Modify: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/run.sh`
- Modify: `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/run_user.sh`

**Step 1:** Update `run.sh`:

```bash
#!/bin/bash

SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)

CONTEXT_DIR=$SCRIPT_DIR/docker
IMAGE_TAG=sb-ubuntu-noble-fw-opensnitch

docker run -it --rm --name "${IMAGE_TAG}-local" \
    --cap-add NET_ADMIN \
    --cap-add NET_RAW \
    --cap-add SETUID \
    --cap-add SETGID \
    --cap-add DAC_OVERRIDE \
    --cap-add CHOWN \
    $IMAGE_TAG /bin/bash
```

**Step 2:** Update `run_user.sh`:

```bash
#!/bin/bash

SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)

CONTEXT_DIR=$SCRIPT_DIR/docker
IMAGE_TAG=sb-ubuntu-noble-fw-opensnitch

docker run -it --rm --name "${IMAGE_TAG}-local" \
    --cap-add NET_ADMIN \
    --cap-add NET_RAW \
    --cap-add SETUID \
    --cap-add SETGID \
    --cap-add DAC_OVERRIDE \
    --cap-add CHOWN \
    -u 1000:1000 \
    $IMAGE_TAG /bin/bash
```

**Step 3: Commit**

```bash
git add templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/run.sh
git add templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/run_user.sh
git commit -m "feat: add --cap-add flags to run.sh and run_user.sh for firewall testing"
```

---

## Task 11: Build and Validate the Image

Build the Docker image and validate that the OpenSnitch firewall works correctly.

**Files:** None (validation only)

**Step 1: Build the image**

```bash
./templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/build.sh
```

Expected: Build completes successfully. Watch for:
- OpenSnitch .deb download and install
- Go toolchain download and install
- opensnitch-controller compilation (protobuf + Go build)
- Go toolchain removal
- Config file copy

**Step 2: Start an ephemeral container**

```bash
./templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/run.sh
```

This starts a container as root with the necessary capabilities.

**Step 3: Verify OpenSnitch is installed**

Inside the container:

```bash
# Check opensnitchd binary exists
which opensnitchd
# Expected: /usr/bin/opensnitchd

# Check opensnitch-controller wrapper exists
which opensnitch-controller
# Expected: /usr/local/bin/opensnitch-controller

# Check controller binary exists
ls -la /usr/local/sbin/opensnitch-controller
# Expected: -rwx------ 1 root root ... /usr/local/sbin/opensnitch-controller

# Check config files
cat /etc/opensnitchd/default-config.json | jq .DefaultAction
# Expected: "deny"

cat /etc/opensnitchd/default-config.json | jq .Rules.Path
# Expected: "/sandbox/firewall/rules"

# Check Go is removed
which go
# Expected: not found (exit 1)
```

**Step 4: Initialize the firewall manually**

Inside the container (as root):

```bash
# Create rules directory (normally populated from volume)
mkdir -p /sandbox/firewall/rules /sandbox/firewall/logs

# Start the firewall
/usr/local/bin/firewall-init.sh
# Expected: opensnitchd starts, logs show success
```

**Step 5: Test ALLOWED traffic**

Inside the container (in a new shell, or after firewall init):

```bash
# Test DNS resolution works
dig +short github.com
# Expected: IP addresses returned

# Test allowed domains (these have allow rules)
curl -s --connect-timeout 10 https://api.github.com/zen
# Expected: Success (200 OK, returns a GitHub zen phrase)

curl -s --connect-timeout 10 -o /dev/null -w "%{http_code}" https://registry.npmjs.org
# Expected: 200

curl -s --connect-timeout 10 -o /dev/null -w "%{http_code}" https://api.anthropic.com
# Expected: Some HTTP response (401/403 without auth, but connection succeeds)

# Test localhost connectivity
curl -s --connect-timeout 5 http://127.0.0.1:1234 2>&1 || true
# Expected: Connection refused (not blocked by firewall - localhost is allowed)

# Test ping to allowed destination
ping -c 1 -W 5 github.com
# Expected: ICMP should work (system-fw.json has ICMP allow rules)
```

**Step 6: Test BLOCKED traffic**

Inside the container:

```bash
# Test blocked domains (no allow rules)
curl -s --connect-timeout 10 https://example.com 2>&1
# Expected: Connection timeout or refused (blocked by default-deny policy)

curl -s --connect-timeout 10 https://httpbin.org/get 2>&1
# Expected: Connection timeout or refused

# Test with netcat (TCP connection to unlisted host)
nc -z -w 5 example.com 443
# Expected: Connection timeout (exit code 1)

nc -z -w 5 httpbin.org 80
# Expected: Connection timeout (exit code 1)
```

**Step 7: Verify opensnitchd healthcheck**

```bash
pgrep -x opensnitchd
# Expected: PID of running daemon

# Check daemon logs
cat /sandbox/firewall/logs/opensnitchd.log | head -20
# Expected: Daemon startup messages, no errors
```

**Step 8:** Exit the container and note any issues.

```bash
exit
```

---

## Summary: File Inventory

### New Files Created (24 total)

| File | Source |
|------|--------|
| `image/docker/opensnitch-controller/main.go` | Copy from agentic-devcontainer |
| `image/docker/opensnitch-controller/ui.proto` | Copy from agentic-devcontainer |
| `image/docker/opensnitch-controller/go.mod` | Copy from agentic-devcontainer |
| `image/docker/opensnitch-controller/go.sum` | Copy from agentic-devcontainer |
| `image/docker/opensnitch-controller/.gitignore` | Copy from agentic-devcontainer |
| `image/docker/firewall/opensnitchd.default-config.json` | Adapted (paths changed) |
| `image/docker/firewall/opensnitchd.system-fw.json` | Copy from agentic-devcontainer |
| `image/docker/firewall-init.sh` | New (adapted from agentic-devcontainer) |
| `artifacts-sandbox/sandbox/firewall/rules/*.json` (17 files) | Copy from agentic-devcontainer |
| `artifacts-sandbox/sandbox/firewall/logs/README.md` | New placeholder |

### Modified Files (6 total)

| File | Change |
|------|--------|
| `image/docker/Dockerfile` | Major rewrite: install OpenSnitch, Go, build controller, configure sudoers |
| `image/run.sh` | Add `--cap-add` flags |
| `image/run_user.sh` | Add `--cap-add` flags |
| `artifacts-host/docker-compose.yml` | Enable caps, add healthcheck, FIREWALL_ENABLED, firewall volume |
| `artifacts-host/sb-sandbox.env` | Add `SB_SANDBOX_FIREWALL_ROOT` |
| `artifacts-sandbox/sandbox/hooks/init/init.sh` | Add firewall init step |
| `hooks/create/post-container-create.sh` | Fix artifact overlay to use `docker compose cp` |
