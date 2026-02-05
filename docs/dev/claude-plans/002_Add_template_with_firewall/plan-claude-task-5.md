# Detailed Plan: Task 5 - Implement Firewall Capability in sb-ubuntu-noble-fw

## Overview

Implement domain-based egress firewall filtering in the `sb-ubuntu-noble-fw` Docker template, using Anthropic's Claude Code devcontainer as the reference implementation. The firewall restricts outbound network access to only explicitly allowed domains/IPs.

## Reference Implementation Analysis

The Anthropic devcontainer firewall implementation consists of:

1. **Docker Capabilities** (`devcontainer.json` lines 12-15):
   - `NET_ADMIN` - Required to modify iptables/ipset rules
   - `NET_RAW` - Required for raw socket operations

2. **Required Packages** (`Dockerfile` lines 20-25):
   - `iptables` - Firewall rule management (already in base image)
   - `ipset` - IP set management for efficient matching
   - `iproute2` - Network utilities (`ip route`)
   - `dnsutils` - DNS lookup (`dig`)
   - `aggregate` - CIDR aggregation tool
   - `jq` - JSON parsing (already in base image)

3. **Firewall Script** (`init-firewall.sh`):
   - Preserves Docker internal DNS rules
   - Flushes existing iptables/ipset rules
   - Creates `allowed-domains` ipset with CIDR support
   - Allows DNS (port 53), SSH (port 22), localhost traffic
   - Fetches GitHub IP ranges from API and adds to allowlist
   - Resolves specific domains and adds IPs to allowlist
   - Sets default DROP policy for INPUT/OUTPUT/FORWARD
   - Allows established connections
   - Allows traffic to ipset members
   - Rejects all other traffic with ICMP admin-prohibited
   - Verifies firewall blocks example.com but allows api.github.com

4. **Execution**: Runs via `postStartCommand: sudo /usr/local/bin/init-firewall.sh`

## Implementation Steps

### Step 1: Update sb-ubuntu-noble-fw Dockerfile

Add firewall packages to the Dockerfile.

**File**: `templates/sandboxes/sb-ubuntu-noble-fw/image/docker/Dockerfile`

```dockerfile
FROM sb-ubuntu-noble

# sb-ubuntu-noble-fw extends sb-ubuntu-noble with firewall capabilities

# Install firewall-related packages
# Note: iptables and jq are already in base image
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends \
    ipset \
    iproute2 \
    dnsutils \
    aggregate \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy firewall initialization script
COPY init-firewall.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-firewall.sh

# Allow sandbox user to run firewall script with sudo (no password)
RUN . /sandbox/user/sb-login.env && \
    echo "$SB_LOGIN_USER_NAME ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/firewall && \
    chmod 0440 /etc/sudoers.d/firewall
```

### Step 2: Create init-firewall.sh Script

Create the firewall initialization script.

**File**: `templates/sandboxes/sb-ubuntu-noble-fw/image/docker/init-firewall.sh`

This script should be adapted from the reference implementation with the following considerations:

1. **Allowed domains** - Configure for sandbox use case (may differ from devcontainer):
   - `api.github.com`, `github.com` - GitHub access
   - `api.anthropic.com` - Claude API
   - `registry.npmjs.org` - NPM packages
   - Additional domains as needed

2. **Error handling** - Use `set -euo pipefail` for strict error handling

3. **Verification** - Include firewall verification tests

```bash
#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_NAME=$(basename "$0")

echo "$SCRIPT_NAME: Initializing firewall..."

# 1. Extract Docker DNS info BEFORE any flushing
DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

# Flush existing rules and delete existing ipsets
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
ipset destroy allowed-domains 2>/dev/null || true

# 2. Restore Docker internal DNS resolution
if [ -n "$DOCKER_DNS_RULES" ]; then
    echo "$SCRIPT_NAME: Restoring Docker DNS rules..."
    iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
    iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
    echo "$DOCKER_DNS_RULES" | xargs -L 1 iptables -t nat
else
    echo "$SCRIPT_NAME: No Docker DNS rules to restore"
fi

# Allow DNS and localhost before any restrictions
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Create ipset with CIDR support
ipset create allowed-domains hash:net

# Fetch GitHub IP ranges
echo "$SCRIPT_NAME: Fetching GitHub IP ranges..."
gh_ranges=$(curl -s https://api.github.com/meta)
if [ -z "$gh_ranges" ]; then
    echo "$SCRIPT_NAME: ERROR: Failed to fetch GitHub IP ranges"
    exit 1
fi

if ! echo "$gh_ranges" | jq -e '.web and .api and .git' >/dev/null; then
    echo "$SCRIPT_NAME: ERROR: GitHub API response missing required fields"
    exit 1
fi

echo "$SCRIPT_NAME: Processing GitHub IPs..."
while read -r cidr; do
    if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        echo "$SCRIPT_NAME: ERROR: Invalid CIDR range from GitHub meta: $cidr"
        exit 1
    fi
    echo "$SCRIPT_NAME: Adding GitHub range $cidr"
    ipset add allowed-domains "$cidr"
done < <(echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' | aggregate -q)

# Resolve and add other allowed domains
for domain in \
    "registry.npmjs.org" \
    "api.anthropic.com" \
    "sentry.io" \
    "statsig.anthropic.com" \
    "statsig.com"; do
    echo "$SCRIPT_NAME: Resolving $domain..."
    ips=$(dig +noall +answer A "$domain" | awk '$4 == "A" {print $5}')
    if [ -z "$ips" ]; then
        echo "$SCRIPT_NAME: WARNING: Failed to resolve $domain (continuing)"
        continue
    fi

    while read -r ip; do
        if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "$SCRIPT_NAME: WARNING: Invalid IP from DNS for $domain: $ip"
            continue
        fi
        echo "$SCRIPT_NAME: Adding $ip for $domain"
        ipset add allowed-domains "$ip" 2>/dev/null || true
    done < <(echo "$ips")
done

# Get host IP from default route
HOST_IP=$(ip route | grep default | cut -d" " -f3)
if [ -z "$HOST_IP" ]; then
    echo "$SCRIPT_NAME: ERROR: Failed to detect host IP"
    exit 1
fi

HOST_NETWORK=$(echo "$HOST_IP" | sed "s/\.[0-9]*$/.0\/24/")
echo "$SCRIPT_NAME: Host network detected as: $HOST_NETWORK"

# Allow host network communication
iptables -A INPUT -s "$HOST_NETWORK" -j ACCEPT
iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT

# Set default policies to DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow traffic to allowed domains
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT

# Reject all other outbound traffic
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

echo "$SCRIPT_NAME: Firewall configuration complete"

# Verification
echo "$SCRIPT_NAME: Verifying firewall rules..."
if curl --connect-timeout 5 https://example.com >/dev/null 2>&1; then
    echo "$SCRIPT_NAME: ERROR: Firewall verification failed - was able to reach https://example.com"
    exit 1
else
    echo "$SCRIPT_NAME: Verification passed - blocked access to example.com"
fi

if ! curl --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
    echo "$SCRIPT_NAME: ERROR: Firewall verification failed - unable to reach https://api.github.com"
    exit 1
else
    echo "$SCRIPT_NAME: Verification passed - allowed access to api.github.com"
fi

echo "$SCRIPT_NAME: Firewall initialization complete"
```

### Step 3: Update docker-compose.yml for Firewall Capabilities

Uncomment/add the NET_ADMIN and NET_RAW capabilities.

**File**: `templates/sandboxes/sb-ubuntu-noble-fw/artifacts/docker-compose.yml`

Change lines 14-24 from commented to active:

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

### Step 4: Create firewall-init.sh Hook Script

Create an initialization hook that runs the firewall setup.

**File**: `templates/sandboxes/sb-ubuntu-noble-fw/artifacts/volumes/sb-hooks/init/firewall-init.sh`

```bash
#!/bin/bash

SCRIPT_NAME=$(basename "$0")

echo ""
echo "$SCRIPT_NAME: Initializing firewall..."

if [ -x /usr/local/bin/init-firewall.sh ]; then
    sudo /usr/local/bin/init-firewall.sh
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "$SCRIPT_NAME: Firewall initialization failed with exit code $exit_code"
    fi
    exit $exit_code
else
    echo "$SCRIPT_NAME: WARNING: Firewall script not found at /usr/local/bin/init-firewall.sh"
    exit 1
fi
```

### Step 5: Update init.sh to Call Firewall Initialization

Modify the sandbox-specific init.sh to include firewall initialization.

**File**: `templates/sandboxes/sb-ubuntu-noble-fw/artifacts/volumes/sb-hooks/init/init.sh`

This file should extend the base init.sh to add firewall initialization as the last step (after all other network-dependent initialization completes):

```bash
#!/bin/bash

SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)

init_status=0

# ----- Init: SSH ------
$SCRIPT_DIR/ssh-init.sh
ssh_init=$?

# ----- Init: nuget ------
$SCRIPT_DIR/nuget-init.sh
nuget_init=$?

# ----- Init: nvm/node ------
$SCRIPT_DIR/nvm-init.sh
nvm_init_status=$?

# ----- Init: Claude
$SCRIPT_DIR/claude-init.sh
claude_init_status=$?

# ----- Init: modules ------
$SCRIPT_DIR/modules-init.sh
module_init=$?

# ----- Init: Firewall (LAST - after all network-dependent initialization) ------
$SCRIPT_DIR/firewall-init.sh
firewall_init=$?

echo ""
if [ $nuget_init -ne 0 ]; then
  init_status=1
  echo "$SCRIPT_NAME: Warning- NuGet initialization failed"
  echo ""
fi
if [ $ssh_init -ne 0 ]; then
  init_status=1
  echo "$SCRIPT_NAME: Warning- SSH initialization failed"
  echo ""
fi
if [ $module_init -ne 0 ]; then
  init_status=1
  echo "$SCRIPT_NAME: Warning- module initialization failed"
  echo ""
fi
if [ $nvm_init_status -ne 0 ]; then
  init_status=1
  echo "$SCRIPT_NAME: Warning- nvm/node initialization failed"
  echo ""
fi
if [ $claude_init_status -ne 0 ]; then
  init_status=1
  echo "$SCRIPT_NAME: Warning- Claude initialization failed"
  echo ""
fi
if [ $firewall_init -ne 0 ]; then
  init_status=1
  echo "$SCRIPT_NAME: ERROR- Firewall initialization failed"
  echo ""
fi

if [ $init_status -ne 0 ]; then
  echo "$SCRIPT_NAME: Sandbox initialization completed with error(s)"
  echo ""
  echo "$SCRIPT_NAME: Run 'sb logs ${SB_SANDBOX_ID}' to view logs"
else
  echo "$SCRIPT_NAME: Sandbox initialization successful"
  echo ""
  echo "$SCRIPT_NAME: Run 'sb shell ${SB_SANDBOX_ID}' to start a shell session"
fi

echo ""
echo "sleep infinity"
exec sleep infinity
```

### Step 6: Update build.sh to Copy Firewall Script

Ensure the firewall script is included when building the image.

**File**: `templates/sandboxes/sb-ubuntu-noble-fw/image/build.sh`

Verify/update to ensure `init-firewall.sh` is in the Docker build context.

## Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `templates/sandboxes/sb-ubuntu-noble-fw/image/docker/Dockerfile` | Edit | Add firewall packages, copy script, configure sudoers |
| `templates/sandboxes/sb-ubuntu-noble-fw/image/docker/init-firewall.sh` | Create | Main firewall initialization script |
| `templates/sandboxes/sb-ubuntu-noble-fw/artifacts/docker-compose.yml` | Edit | Uncomment cap_add for NET_ADMIN, NET_RAW |
| `templates/sandboxes/sb-ubuntu-noble-fw/artifacts/volumes/sb-hooks/init/firewall-init.sh` | Create | Hook script to call firewall init |
| `templates/sandboxes/sb-ubuntu-noble-fw/artifacts/volumes/sb-hooks/init/init.sh` | Create | Extended init.sh with firewall step |

## Directory Structure After Implementation

```
templates/sandboxes/sb-ubuntu-noble-fw/
├── artifacts/
│   ├── docker-compose.yml          # Updated with cap_add
│   ├── volumes/
│   │   └── sb-hooks/
│   │       └── init/
│   │           ├── init.sh         # Extended with firewall init
│   │           └── firewall-init.sh # New: calls sudo init-firewall.sh
│   └── ...
├── image/
│   ├── docker/
│   │   ├── Dockerfile              # Updated with packages/script
│   │   └── init-firewall.sh        # New: main firewall script
│   └── build.sh
└── hooks/
    └── ...
```

## Testing

1. **Build the image**:
   ```bash
   ./templates/sandboxes/sb-ubuntu-noble-fw/image/build.sh
   ```

2. **Create and start a sandbox**:
   ```bash
   cd <test-project>
   sb new -t sb-ubuntu-noble-fw
   sb up
   sb logs -f  # Watch initialization
   ```

3. **Verify firewall is active**:
   ```bash
   sb shell
   # Inside container:
   curl https://example.com        # Should fail/timeout
   curl https://api.github.com/zen # Should succeed
   curl https://api.anthropic.com  # Should succeed
   iptables -L -n                  # View rules
   ipset list allowed-domains      # View allowed IPs
   ```

4. **Verify capabilities**:
   ```bash
   docker inspect <container-name> | jq '.[0].HostConfig.CapAdd'
   # Should show: ["NET_ADMIN", "NET_RAW", ...]
   ```

## Security Considerations

1. **Minimum capabilities**: Only NET_ADMIN and NET_RAW are added for firewall management
2. **Sudo restriction**: User can only run the specific firewall script with sudo
3. **Default deny**: All traffic is blocked by default; only allowlisted destinations are permitted
4. **DNS allowed**: Port 53 is open to allow domain resolution (required for the firewall to function)
5. **Host network allowed**: Container can communicate with Docker host network for Docker functionality

## Rationale

1. **ipset over iptables rules**: Using ipset is more efficient for large numbers of IPs than individual iptables rules
2. **GitHub API for IP ranges**: GitHub publishes their IP ranges via API, ensuring the allowlist stays current
3. **Firewall last in init**: Running firewall setup after other initialization allows network-dependent init scripts (nvm, claude, etc.) to complete successfully before network restrictions are applied
4. **Verification tests**: Built-in verification ensures the firewall is working as expected before container is marked ready
