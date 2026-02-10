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
RUN . /sandbox/build/sb-login.env && \
    echo "$SB_LOGIN_USER_NAME ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/firewall && \
    chmod 0440 /etc/sudoers.d/firewall
