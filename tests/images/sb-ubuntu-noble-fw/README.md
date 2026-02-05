# Firewall Integration Tests for sb-ubuntu-noble-fw

This directory contains integration tests for validating the firewall functionality in the `sb-ubuntu-noble-fw` Docker image.

## Overview

The tests use [Bats (Bash Automated Testing System)](https://github.com/bats-core/bats-core) to verify that the firewall:

1. **Allows** traffic to approved destinations (GitHub, npm, Anthropic API, etc.)
2. **Blocks** traffic to unapproved destinations (example.com, google.com, etc.)
3. **Is configured correctly** (DROP policies, ipset rules, etc.)

## Files

| File | Purpose |
|------|---------|
| `run-tests.sh` | Host-side test runner script |
| `firewall.bats` | Bats test file with all test cases |
| `test_helper.bash` | Shared helper functions |
| `README.md` | This documentation |

## Running Tests

### Basic Usage

```bash
./tests/images/sb-ubuntu-noble-fw/run-tests.sh
```

This will:
1. Build the `sb-ubuntu-noble-fw` Docker image (and parent image)
2. Start a container with required capabilities
3. Initialize the firewall
4. Install Bats (if needed)
5. Run all tests
6. Clean up

### Options

```bash
# Skip the image build step (use existing image)
./run-tests.sh --skip-build

# Verbose output
./run-tests.sh --verbose

# Show help
./run-tests.sh --help
```

## Test Categories

### Allowed Destinations (A1-A8)

Tests that verify connectivity to approved services:

| Test | Description | Command |
|------|-------------|---------|
| A1 | GitHub API | `curl https://api.github.com/zen` |
| A2 | npm registry | `curl https://registry.npmjs.org/` |
| A3 | Anthropic API | `curl https://api.anthropic.com` |
| A4 | Sentry | `curl https://sentry.io` |
| A5 | Statsig | `curl https://statsig.com` |
| A6 | DNS resolution | `dig github.com` |
| A7 | Localhost ping | `ping 127.0.0.1` |
| A8 | GitHub SSH | `nc -z github.com 22` |

### Blocked Destinations (B1-B5)

Tests that verify traffic is blocked to unapproved destinations:

| Test | Description | Command |
|------|-------------|---------|
| B1 | example.com | `curl https://example.com` |
| B2 | google.com | `curl https://google.com` |
| B3 | External IP | `ping 8.8.8.8` |
| B4 | Blocked port | `nc -z 8.8.8.8 443` |
| B5 | wikipedia.org | `curl https://wikipedia.org` |

### Configuration Tests (C1-C10)

Tests that verify correct firewall configuration:

| Test | Description |
|------|-------------|
| C1 | INPUT chain policy is DROP |
| C2 | OUTPUT chain policy is DROP |
| C3 | FORWARD chain policy is DROP |
| C4 | DNS outbound rule exists |
| C5 | SSH outbound rule exists |
| C6 | Localhost loopback rule exists |
| C7 | ipset 'allowed-domains' exists |
| C8 | ipset contains entries |
| C9 | ipset match rule in OUTPUT |
| C10 | ESTABLISHED connections allowed |

## Output Format

Tests produce TAP (Test Anything Protocol) compliant output:

```
ok 1 A1: Can reach GitHub API
ok 2 A2: Can reach npm registry
ok 3 A3: Can reach Anthropic API
...
not ok 15 B1: Cannot reach example.com
```

## Requirements

- Docker with internet access
- Bash shell
- The `sb-ubuntu-noble-fw` image must be buildable

## Troubleshooting

### Tests fail to start

Ensure Docker is running and you have permission to use it:
```bash
docker ps
```

### Firewall initialization fails

Check the container logs:
```bash
docker logs <container-name>
```

Common issues:
- Missing `NET_ADMIN` or `NET_RAW` capabilities
- Network connectivity issues during IP range fetching

### "Allowed" tests fail

The firewall fetches IP ranges dynamically. If GitHub or other services have changed their IP ranges, the firewall may not have the latest IPs. Rebuild the image or re-run firewall initialization.

### "Blocked" tests pass when they should fail

This indicates the firewall is not properly blocking traffic. Check:
- Firewall initialization completed successfully
- iptables rules are in place: `sudo iptables -L -n`
- ipset is populated: `sudo ipset list allowed-domains`
