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
RUN cat <<'WRAPPER_EOF' > /usr/local/bin/opensnitch-controller
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
