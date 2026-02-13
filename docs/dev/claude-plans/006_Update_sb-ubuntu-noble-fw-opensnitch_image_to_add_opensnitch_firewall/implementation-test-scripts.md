# Test Scripts: OpenSnitch Firewall Validation

Scripts used to validate the `sb-ubuntu-noble-fw-opensnitch` Docker image after implementation.

---

## Test 1: Build the Image

```bash
./templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/build.sh
```

**Expected:** Build completes successfully. Parent image (`sb-ubuntu-noble`) builds first, then the opensnitch layer adds OpenSnitch daemon, compiles the controller, and configures the image.

---

## Test 2: Validate Without Rules (Default-Deny Baseline)

This test confirms the daemon starts and the default-deny policy blocks all traffic when no rules are present.

```bash
docker run --rm \
    --cap-add NET_ADMIN \
    --cap-add NET_RAW \
    --cap-add SETUID \
    --cap-add SETGID \
    --cap-add DAC_OVERRIDE \
    --cap-add CHOWN \
    sb-ubuntu-noble-fw-opensnitch bash -c '
echo "=== Step 1: Verify OpenSnitch binaries ==="
echo "opensnitchd: $(which opensnitchd)"
echo "opensnitch-controller wrapper: $(which opensnitch-controller)"
ls -la /usr/local/sbin/opensnitch-controller
echo ""

echo "=== Step 2: Verify config files ==="
cat /etc/opensnitchd/default-config.json | jq .DefaultAction
cat /etc/opensnitchd/default-config.json | jq .Rules.Path
echo ""

echo "=== Step 3: Verify Go is removed ==="
which go 2>&1 || echo "Go correctly removed"
echo ""

echo "=== Step 4: Verify sudoers ==="
cat /etc/sudoers.d/firewall
cat /etc/sudoers.d/env-keep-firewall
echo ""

echo "=== Step 5: Verify firewall directory ==="
ls -la /sandbox/firewall/
echo ""

echo "=== Step 6: Initialize firewall ==="
mkdir -p /sandbox/firewall/rules /sandbox/firewall/logs
export FIREWALL_ENABLED=true
/usr/local/bin/firewall-init.sh
sleep 2
echo ""

echo "=== Step 7: Check daemon is running ==="
if pgrep -x opensnitchd; then
    echo "opensnitchd is running"
else
    echo "FAIL: opensnitchd is NOT running"
    cat /sandbox/firewall/logs/opensnitchd.log 2>/dev/null | head -30
fi
echo ""

echo "=== Step 8: Test ALLOWED traffic ==="
echo "Testing DNS (github.com)..."
dig +short github.com | head -2
echo ""

echo "Testing curl to github.com..."
curl -s --connect-timeout 10 -o /dev/null -w "github.com: HTTP %{http_code}\n" https://api.github.com/zen 2>&1 || echo "github.com: FAILED"

echo "Testing curl to registry.npmjs.org..."
curl -s --connect-timeout 10 -o /dev/null -w "registry.npmjs.org: HTTP %{http_code}\n" https://registry.npmjs.org 2>&1 || echo "registry.npmjs.org: FAILED"

echo "Testing curl to api.anthropic.com..."
curl -s --connect-timeout 10 -o /dev/null -w "api.anthropic.com: HTTP %{http_code}\n" https://api.anthropic.com 2>&1 || echo "api.anthropic.com: FAILED"

echo ""
echo "=== Step 9: Test BLOCKED traffic ==="
echo "Testing curl to example.com (should be blocked)..."
curl -s --connect-timeout 10 -o /dev/null -w "example.com: HTTP %{http_code}\n" https://example.com 2>&1 || echo "example.com: connection blocked/failed (EXPECTED)"

echo "Testing curl to httpbin.org (should be blocked)..."
curl -s --connect-timeout 10 -o /dev/null -w "httpbin.org: HTTP %{http_code}\n" https://httpbin.org/get 2>&1 || echo "httpbin.org: connection blocked/failed (EXPECTED)"

echo "Testing netcat to example.com:443 (should be blocked)..."
nc -z -w 5 example.com 443 2>&1 && echo "example.com:443 CONNECTED (UNEXPECTED)" || echo "example.com:443 blocked (EXPECTED)"

echo ""
echo "=== VALIDATION COMPLETE ==="
'
```

**Expected results (no rules loaded):**
- Steps 1-7: All pass (binaries present, config correct, daemon running)
- Step 8: ALL traffic blocked (HTTP 000 / timeouts) — default-deny with no allow rules
- Step 9: All traffic blocked (expected)

---

## Test 3: Validate With Rules (Full Firewall Test)

This test mounts the rule files and validates the allow/deny behavior.

```bash
RULES_SRC="/home/tellis/dev/ai-tools/agent-sandboxes/git/ai-agents-sandboxes/templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/artifacts-sandbox/sandbox/firewall/rules"

docker run --rm \
    --cap-add NET_ADMIN \
    --cap-add NET_RAW \
    --cap-add SETUID \
    --cap-add SETGID \
    --cap-add DAC_OVERRIDE \
    --cap-add CHOWN \
    -v "$RULES_SRC:/sandbox/firewall/rules:ro" \
    sb-ubuntu-noble-fw-opensnitch bash -c '
echo "=== Initialize firewall with rules ==="
export FIREWALL_ENABLED=true
mkdir -p /sandbox/firewall/logs
/usr/local/bin/firewall-init.sh
sleep 3
echo ""

echo "=== Rules loaded ==="
ls /sandbox/firewall/rules/*.json | wc -l
echo ""

echo "=== Daemon status ==="
pgrep -x opensnitchd && echo "opensnitchd running" || echo "FAIL: not running"
echo ""

echo "=== Test ALLOWED traffic ==="
echo "DNS (github.com):"
dig +short github.com 2>&1 | head -2

echo "curl github.com:"
curl -s --connect-timeout 15 -o /dev/null -w "  HTTP %{http_code}\n" https://api.github.com/zen 2>&1 || echo "  FAILED"

echo "curl registry.npmjs.org:"
curl -s --connect-timeout 15 -o /dev/null -w "  HTTP %{http_code}\n" https://registry.npmjs.org 2>&1 || echo "  FAILED"

echo "curl api.anthropic.com:"
curl -s --connect-timeout 15 -o /dev/null -w "  HTTP %{http_code}\n" https://api.anthropic.com 2>&1 || echo "  FAILED"

echo ""
echo "=== Test BLOCKED traffic ==="
echo "curl example.com (should block):"
curl -s --connect-timeout 10 -o /dev/null -w "  HTTP %{http_code}\n" https://example.com 2>&1 || echo "  blocked (EXPECTED)"

echo "nc example.com:443 (should block):"
nc -z -w 5 example.com 443 2>&1 && echo "  CONNECTED (UNEXPECTED)" || echo "  blocked (EXPECTED)"

echo ""
echo "=== VALIDATION COMPLETE ==="
'
```

**Expected results (17 rules loaded):**
- 17 rules loaded, daemon running
- **ALLOWED:** `github.com` → DNS resolves, HTTP 200
- **ALLOWED:** `registry.npmjs.org` → HTTP 200
- **ALLOWED:** `api.anthropic.com` → HTTP 404 (connected successfully, auth required)
- **BLOCKED:** `example.com` → HTTP 000 (connection refused/timeout)
- **BLOCKED:** `nc example.com:443` → blocked

---

## Actual Test Results (2026-02-12)

### Test 2 Results (No Rules)

```
=== Step 1: Verify OpenSnitch binaries ===
opensnitchd: /usr/bin/opensnitchd
opensnitch-controller wrapper: /usr/local/sbin/opensnitch-controller
-rwx------ 1 root root 10330296 Feb 12 23:16 /usr/local/sbin/opensnitch-controller

=== Step 2: Verify config files ===
"deny"
"/sandbox/firewall/rules"

=== Step 3: Verify Go is removed ===
Go correctly removed

=== Step 4: Verify sudoers ===
ubuntu ALL=(root) NOPASSWD: /usr/local/bin/firewall-init.sh
Defaults env_keep += "FIREWALL_ENABLED"

=== Step 6: Initialize firewall ===
[firewall-init.sh] opensnitchd started (PID: 41)
[firewall-init.sh] OpenSnitch firewall initialized successfully

=== Step 7: Check daemon is running ===
41
opensnitchd is running

=== Step 8: Test ALLOWED traffic ===
(all blocked — no rules loaded, default-deny working correctly)

=== Step 9: Test BLOCKED traffic ===
example.com: connection blocked/failed (EXPECTED)
httpbin.org: connection blocked/failed (EXPECTED)
example.com:443 blocked (EXPECTED)
```

### Test 3 Results (With Rules)

```
=== Rules loaded ===
17

=== Daemon status ===
30
opensnitchd running

=== Test ALLOWED traffic ===
DNS (github.com):
140.82.112.3
curl github.com:
  HTTP 200
curl registry.npmjs.org:
  HTTP 200
curl api.anthropic.com:
  HTTP 404

=== Test BLOCKED traffic ===
curl example.com (should block):
  blocked (EXPECTED)
nc example.com:443 (should block):
  blocked (EXPECTED)
```

**Conclusion:** All tests pass. The OpenSnitch firewall is fully functional with default-deny policy and allowlist rules working correctly.
