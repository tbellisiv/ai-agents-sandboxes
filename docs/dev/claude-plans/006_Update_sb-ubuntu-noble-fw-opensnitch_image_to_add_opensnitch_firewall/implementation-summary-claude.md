# Implementation Summary: Add OpenSnitch Firewall to sb-ubuntu-noble-fw-opensnitch

**Date:** 2026-02-12
**Plan:** `plan-claude.md`
**Reference:** `agentic-devcontainer` at `/home/tellis/dev/ai-tools/agent-sandboxes/devcontainers/git/agentic-devcontainer/.devcontainer/`

---

## Tasks Executed

### Task 1: Copy opensnitch-controller Go Source

Copied 5 files verbatim from the agentic-devcontainer reference:

| File | Size |
|------|------|
| `image/docker/opensnitch-controller/main.go` | 11,147 bytes |
| `image/docker/opensnitch-controller/ui.proto` | 6,879 bytes |
| `image/docker/opensnitch-controller/go.mod` | 364 bytes |
| `image/docker/opensnitch-controller/go.sum` | 2,943 bytes |
| `image/docker/opensnitch-controller/.gitignore` | 51 bytes |

### Task 2: Create OpenSnitch Daemon Config Files

Created 2 config files in `image/docker/firewall/`:

- **`opensnitchd.default-config.json`** — Adapted from reference. Key changes:
  - `Server.LogFile` → `/sandbox/firewall/logs/opensnitchd.log`
  - `Rules.Path` → `/sandbox/firewall/rules`
  - `DefaultAction: "deny"`, `Firewall: "nftables"`
- **`opensnitchd.system-fw.json`** — Copied verbatim. Defines nftables chains (filter, mangle, nat) with ICMP/ICMPv6 allow rules.

### Task 3: Create firewall-init.sh Script

Created `image/docker/firewall-init.sh` — adapted from the agentic-devcontainer's `scripts/firewall-init.sh`. Key adaptations:

- Removed `DEVCONTAINER` environment check
- Log paths changed to `/sandbox/firewall/logs/`
- Rules path changed to `/sandbox/firewall/rules/`
- Supports `FIREWALL_ENABLED` env var to skip initialization
- Creates log files with symlink attack prevention
- Protects gRPC port 50051 via nftables (root-only access)
- Starts opensnitchd daemon in background, verifies it stays running
- Non-blocking on failure (container continues without firewall)

### Task 4: Rewrite Dockerfile

Replaced the minimal `FROM sb-ubuntu-noble` with a full Dockerfile that:

1. Installs OpenSnitch daemon v1.7.2 from GitHub releases (.deb)
2. Installs Go 1.25.5 toolchain (temporary, for build only)
3. Compiles opensnitch-controller from source (protobuf + Go gRPC)
4. Removes Go toolchain after build (~500MB savings)
5. Copies opensnitchd config files to `/etc/opensnitchd/`
6. Copies `firewall-init.sh` to `/usr/local/bin/`
7. Configures sudoers:
   - Sandbox user can run `firewall-init.sh` without password
   - `opensnitch-controller` requires root password (rootpw)
   - `FIREWALL_ENABLED` env var passed through sudo
8. Creates wrapper script at `/usr/local/bin/opensnitch-controller`
9. Creates `/sandbox/firewall/{rules,logs}` directories

### Task 5: Create Firewall Rules in artifacts-sandbox

Copied all 17 rule JSON files verbatim from the agentic-devcontainer to `artifacts-sandbox/sandbox/firewall/rules/`:

**Allow rules (precedence/infrastructure):**
- `000-allow-localhost.json` — regexp matching `127.0.0.1` and `::1`
- `001-allow-dns.json` — list rule for Cloudflare DNS (1.1.1.1, 1.0.0.1) + localhost
- `002-allow-rfc1918.json` — regexp matching RFC1918 private networks
- `allow-127.0.0.11.json` — Docker's embedded DNS server

**Allow rules (services):**
- `010-allow-github.json` — `*.github.com`
- `011-allow-githubusercontent.json` — `*.githubusercontent.com`
- `020-allow-npm.json` — `registry.npmjs.org`
- `021-allow-go.json` — Go proxy, sum, storage
- `025-allow-ghcr.json` — `ghcr.io`, `*.pkg.github.com`
- `030-allow-anthropic.json` — `api.anthropic.com`, `statsig.anthropic.com`, `*.console.anthropic.com`
- `040-allow-vscode-marketplace.json` — VSCode marketplace domains
- `041-allow-openvsx.json` — OpenVSX extension registry
- `050-allow-google-gemini.json` — Google Gemini APIs and OAuth
- `allow-json.schemastore.org.json` — JSON schema store
- `allow-www.schemastore.org.json` — WWW schema store

**Deny rules:**
- `deny-http-intake.logs.datadoghq.com.json` — Blocks Datadog logging
- `deny-http-intake.logs.us5.datadoghq.com.json` — Blocks Datadog regional logging

Also created `artifacts-sandbox/sandbox/firewall/logs/README.md` as directory placeholder.

### Task 6: Update docker-compose.yml

Modified `artifacts-host/docker-compose.yml`:

1. **Enabled capabilities** (were commented out):
   - `cap_drop: ALL`
   - `cap_add: NET_ADMIN, NET_RAW, SETUID, SETGID, DAC_OVERRIDE, CHOWN`
2. **Added healthcheck** — `pgrep -x opensnitchd` (60s interval, 30s startup)
3. **Added environment** — `FIREWALL_ENABLED=true`
4. **Added firewall volume** — `firewall:${SB_SANDBOX_FIREWALL_ROOT}`
5. **Added named volume** — `firewall:` in top-level volumes section

### Task 7: Add SB_SANDBOX_FIREWALL_ROOT to sb-sandbox.env

Added `SB_SANDBOX_FIREWALL_ROOT=/sandbox/firewall` to `artifacts-host/sb-sandbox.env`.

### Task 8: Update init.sh to Call Firewall Init

Modified `artifacts-sandbox/sandbox/hooks/init/init.sh`:

- Added `sudo /usr/local/bin/firewall-init.sh` call after Claude init, before modules init
- Added error reporting block for `firewall_init` exit code

### Task 9: Fix post-container-create.sh

Replaced the commented-out `cp -r -f` (host copy) with proper `docker compose cp` implementation:

- Sources `sb-compose.env` to get `SB_COMPOSE_SERVICE`
- Uses `docker compose -f $compose_file_path cp $template_artifacts_path/. ${SB_COMPOSE_SERVICE}:/`
- Includes error handling for missing env file, missing compose service, and copy failure

### Task 10: Update run.sh and run_user.sh

Added `--cap-add` flags to both scripts: `NET_ADMIN`, `NET_RAW`, `SETUID`, `SETGID`, `DAC_OVERRIDE`, `CHOWN`.

### Task 11: Build and Validate

**Build:** Successful. Parent image cached, opensnitch-specific layers built in ~25s.

**Validation Results:**

| Check | Result |
|-------|--------|
| `opensnitchd` binary at `/usr/bin/opensnitchd` | Pass |
| `opensnitch-controller` binary at `/usr/local/sbin/` (root:root, mode 700) | Pass |
| Config `DefaultAction: "deny"` | Pass |
| Config `Rules.Path: "/sandbox/firewall/rules"` | Pass |
| Go toolchain removed from final image | Pass |
| Sudoers: sandbox user can run `firewall-init.sh` NOPASSWD | Pass |
| Daemon starts and stays running (PID verified) | Pass |
| 17 firewall rules loaded | Pass |
| **ALLOWED:** `github.com` → DNS resolved, HTTP 200 | Pass |
| **ALLOWED:** `registry.npmjs.org` → HTTP 200 | Pass |
| **ALLOWED:** `api.anthropic.com` → HTTP 404 (connected, auth required) | Pass |
| **BLOCKED:** `example.com` → HTTP 000 (connection refused) | Pass |
| **BLOCKED:** `nc example.com:443` → blocked | Pass |

---

## File Inventory

### New Files (24)

| Path (relative to `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/`) | Source |
|---------|--------|
| `image/docker/opensnitch-controller/main.go` | Verbatim copy |
| `image/docker/opensnitch-controller/ui.proto` | Verbatim copy |
| `image/docker/opensnitch-controller/go.mod` | Verbatim copy |
| `image/docker/opensnitch-controller/go.sum` | Verbatim copy |
| `image/docker/opensnitch-controller/.gitignore` | Verbatim copy |
| `image/docker/firewall/opensnitchd.default-config.json` | Adapted (paths) |
| `image/docker/firewall/opensnitchd.system-fw.json` | Verbatim copy |
| `image/docker/firewall-init.sh` | Adapted |
| `artifacts-sandbox/sandbox/firewall/rules/000-allow-localhost.json` | Verbatim copy |
| `artifacts-sandbox/sandbox/firewall/rules/001-allow-dns.json` | Verbatim copy |
| `artifacts-sandbox/sandbox/firewall/rules/002-allow-rfc1918.json` | Verbatim copy |
| `artifacts-sandbox/sandbox/firewall/rules/010-allow-github.json` | Verbatim copy |
| `artifacts-sandbox/sandbox/firewall/rules/011-allow-githubusercontent.json` | Verbatim copy |
| `artifacts-sandbox/sandbox/firewall/rules/020-allow-npm.json` | Verbatim copy |
| `artifacts-sandbox/sandbox/firewall/rules/021-allow-go.json` | Verbatim copy |
| `artifacts-sandbox/sandbox/firewall/rules/025-allow-ghcr.json` | Verbatim copy |
| `artifacts-sandbox/sandbox/firewall/rules/030-allow-anthropic.json` | Verbatim copy |
| `artifacts-sandbox/sandbox/firewall/rules/040-allow-vscode-marketplace.json` | Verbatim copy |
| `artifacts-sandbox/sandbox/firewall/rules/041-allow-openvsx.json` | Verbatim copy |
| `artifacts-sandbox/sandbox/firewall/rules/050-allow-google-gemini.json` | Verbatim copy |
| `artifacts-sandbox/sandbox/firewall/rules/allow-127.0.0.11.json` | Verbatim copy |
| `artifacts-sandbox/sandbox/firewall/rules/allow-json.schemastore.org.json` | Verbatim copy |
| `artifacts-sandbox/sandbox/firewall/rules/allow-www.schemastore.org.json` | Verbatim copy |
| `artifacts-sandbox/sandbox/firewall/rules/deny-http-intake.logs.datadoghq.com.json` | Verbatim copy |
| `artifacts-sandbox/sandbox/firewall/rules/deny-http-intake.logs.us5.datadoghq.com.json` | Verbatim copy |
| `artifacts-sandbox/sandbox/firewall/logs/README.md` | New |

### Modified Files (7)

| Path | Change |
|------|--------|
| `image/docker/Dockerfile` | Full rewrite: OpenSnitch, Go, controller, sudoers |
| `image/run.sh` | Added `--cap-add` flags |
| `image/run_user.sh` | Added `--cap-add` flags |
| `artifacts-host/docker-compose.yml` | Caps, healthcheck, FIREWALL_ENABLED, firewall volume |
| `artifacts-host/sb-sandbox.env` | Added `SB_SANDBOX_FIREWALL_ROOT` |
| `artifacts-sandbox/sandbox/hooks/init/init.sh` | Added firewall init step + error reporting |
| `hooks/create/post-container-create.sh` | Replaced commented cp with docker compose cp |
