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
