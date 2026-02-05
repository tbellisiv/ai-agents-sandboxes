#!/bin/bash
# test_helper.bash - Shared helper functions for firewall tests

# Default timeout for network operations (seconds)
NETWORK_TIMEOUT=${NETWORK_TIMEOUT:-5}

# Setup function - called before each test
setup() {
    # Ensure we're running as a user that can execute network commands
    # Firewall should already be initialized by the test runner
    :
}

# Teardown function - called after each test
teardown() {
    :
}

# Helper: Run curl with timeout and return status
# Usage: curl_check URL
curl_check() {
    local url="$1"
    curl -s --connect-timeout "$NETWORK_TIMEOUT" -o /dev/null -w "%{http_code}" "$url"
}

# Helper: Check if curl can connect (ignores HTTP status, just checks connectivity)
# Usage: curl_can_connect URL
curl_can_connect() {
    local url="$1"
    curl -s --connect-timeout "$NETWORK_TIMEOUT" -o /dev/null "$url"
}

# Helper: Check if a port is reachable via netcat
# Usage: nc_check HOST PORT
nc_check() {
    local host="$1"
    local port="$2"
    nc -z -w "$NETWORK_TIMEOUT" "$host" "$port"
}

# Helper: Ping with timeout
# Usage: ping_check HOST
ping_check() {
    local host="$1"
    ping -c 1 -W "$NETWORK_TIMEOUT" "$host"
}

# Helper: DNS resolution check
# Usage: dns_check DOMAIN
dns_check() {
    local domain="$1"
    dig +short +time="$NETWORK_TIMEOUT" "$domain"
}

# Helper: Get iptables policy for a chain
# Usage: get_iptables_policy CHAIN
get_iptables_policy() {
    local chain="$1"
    sudo iptables -L "$chain" -n | head -1 | grep -oP 'policy \K\w+'
}

# Helper: Check if ipset exists
# Usage: ipset_exists SETNAME
ipset_exists() {
    local setname="$1"
    sudo ipset list "$setname" >/dev/null 2>&1
}

# Helper: Count entries in ipset
# Usage: ipset_count SETNAME
ipset_count() {
    local setname="$1"
    sudo ipset list "$setname" 2>/dev/null | grep -c "^[0-9]"
}
