#!/usr/bin/env bats
# firewall.bats - Integration tests for sb-ubuntu-noble-fw firewall

load test_helper

# =============================================================================
# ALLOWED DESTINATIONS TESTS
# =============================================================================

@test "A1: Can reach GitHub API" {
    run curl -s --connect-timeout 5 https://api.github.com/zen
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "A2: Can reach npm registry" {
    run curl -s --connect-timeout 5 https://registry.npmjs.org/
    [ "$status" -eq 0 ]
}

@test "A3: Can reach Anthropic API" {
    run curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" https://api.anthropic.com
    [ "$status" -eq 0 ]
    # Accept any HTTP response (even 4xx) as it means we connected
}

@test "A4: Can reach Sentry" {
    run curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" https://sentry.io
    [ "$status" -eq 0 ]
}

@test "A5: Can reach Statsig" {
    run curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" https://statsig.com
    [ "$status" -eq 0 ]
}

@test "A6: DNS resolution works for allowed domains" {
    run dig +short +time=5 github.com
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "A7: Can ping localhost" {
    run ping -c 1 -W 3 127.0.0.1
    [ "$status" -eq 0 ]
}

@test "A8: Can reach GitHub SSH port" {
    run nc -z -w 5 github.com 22
    [ "$status" -eq 0 ]
}

# =============================================================================
# BLOCKED DESTINATIONS TESTS
# =============================================================================

@test "B1: Cannot reach example.com" {
    run curl -s --connect-timeout 5 https://example.com
    [ "$status" -ne 0 ]
}

@test "B2: Cannot reach google.com" {
    run curl -s --connect-timeout 5 https://google.com
    [ "$status" -ne 0 ]
}

@test "B3: Cannot ping external IP (8.8.8.8)" {
    run ping -c 1 -W 3 8.8.8.8
    [ "$status" -ne 0 ]
}

@test "B4: Cannot connect to blocked IP port (8.8.8.8:443)" {
    run nc -z -w 5 8.8.8.8 443
    [ "$status" -ne 0 ]
}

@test "B5: Cannot reach random website (wikipedia.org)" {
    run curl -s --connect-timeout 5 https://wikipedia.org
    [ "$status" -ne 0 ]
}

# =============================================================================
# FIREWALL CONFIGURATION TESTS
# =============================================================================

@test "C1: INPUT chain default policy is DROP" {
    run sudo iptables -L INPUT -n
    [ "$status" -eq 0 ]
    [[ "$output" =~ "policy DROP" ]]
}

@test "C2: OUTPUT chain default policy is DROP" {
    run sudo iptables -L OUTPUT -n
    [ "$status" -eq 0 ]
    [[ "$output" =~ "policy DROP" ]]
}

@test "C3: FORWARD chain default policy is DROP" {
    run sudo iptables -L FORWARD -n
    [ "$status" -eq 0 ]
    [[ "$output" =~ "policy DROP" ]]
}

@test "C4: DNS (UDP 53) outbound rule exists" {
    run sudo iptables -L OUTPUT -n -v
    [ "$status" -eq 0 ]
    [[ "$output" =~ "udp dpt:53" ]]
}

@test "C5: SSH (TCP 22) outbound rule exists" {
    run sudo iptables -L OUTPUT -n -v
    [ "$status" -eq 0 ]
    [[ "$output" =~ "tcp dpt:22" ]]
}

@test "C6: Localhost loopback rule exists" {
    run sudo iptables -L INPUT -n -v
    [ "$status" -eq 0 ]
    [[ "$output" =~ "lo" ]]
}

@test "C7: ipset 'allowed-domains' exists" {
    run sudo ipset list allowed-domains
    [ "$status" -eq 0 ]
}

@test "C8: ipset 'allowed-domains' contains entries" {
    run sudo ipset list allowed-domains
    [ "$status" -eq 0 ]
    # Check that there are IP entries (lines starting with numbers)
    entry_count=$(echo "$output" | grep -cE "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" || echo "0")
    [ "$entry_count" -gt 0 ]
}

@test "C9: ipset match rule exists in OUTPUT chain" {
    run sudo iptables -L OUTPUT -n -v
    [ "$status" -eq 0 ]
    [[ "$output" =~ "allowed-domains" ]]
}

@test "C10: ESTABLISHED,RELATED connections are allowed" {
    run sudo iptables -L INPUT -n -v
    [ "$status" -eq 0 ]
    [[ "$output" =~ "ESTABLISHED" ]] || [[ "$output" =~ "state" ]]
}
