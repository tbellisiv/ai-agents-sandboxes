FROM ubuntu:noble-20260113

#-- Build args
ARG USER_ID
ARG GROUP_ID
ARG SU_HASH
ARG USER_HASH
ARG TZ=UTC
ARG SB_LOGIN_USER_NAME_REQUESTED=sandbox
ARG SB_USER_GROUP_REQUESTED=sandbox

#validation
RUN [ -n "$SU_HASH" ] || { echo "Required Docker build argument 'SU_HASH' is missing or empty- run 'sb-templates init' to generate SU_HASH"; exit 1; }

ENV TZ="$TZ"

#-- System
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    ca-certificates \
    fzf \
    git \
    curl \
    iptables \
    netcat-openbsd \
    iputils-ping \
    dnsutils \    
    net-tools \
    jq \
    yq \
    less \
    nano \
    nftables \
    procps \
    sudo \
#    tmux \
    unzip \
    vim \
    wget \
    openssh-client \
    # required to compile opensnitch-controller:
    protobuf-compiler \
    bash-completion

#-- Initialize workspace mount dir
ENV WORKSPACE_MAIN_ROOT=/workspace/main
RUN mkdir -p /workspace/main

# Create empty directory mount to hide the sandbox project files
RUN mkdir -p /workspace/main/.sb

#-- Initialize sandbox mount dirs mount
ENV SANDBOX_ROOT=/sandbox
ENV SANDBOX_INIT_ROOT=/sandbox/init
ENV SANDBOX_SECRETS_ROOT=/sandbox/secrets
RUN mkdir -p /sandbox/init
RUN mkdir -p /sandbox/secrets

#-- Create directory for info on the user account
RUN mkdir -p /sandbox/user

#get a group with the specified group ID (if exists) or create it (if it doesn't)
COPY get_or_create_sb_group.sh  /tmp
RUN /tmp/get_or_create_sb_group.sh ${GROUP_ID} ${SB_USER_GROUP_REQUESTED} > /sandbox/user/sb-login.env

#get a user with the specified user ID (if exists) or create it (if it doesn't)
COPY get_or_create_sb_user.sh  /tmp
RUN . /sandbox/user/sb-login.env && /tmp/get_or_create_sb_user.sh ${USER_ID} ${SB_LOGIN_USER_NAME_REQUESTED} ${SB_LOGIN_GROUP_NAME} '${USER_HASH}' >> /sandbox/user/sb-login.env

# set root password
RUN if [ -n "$SU_HASH" ]; then \
      usermod -p "$SU_HASH" root && \
      echo "Root password set from SU_HASH"; \
    else \
      echo "WARNING: SU_HASH is empty - root login disabled"; \
    fi

#-- Git safe.directory (allows git in mounted workspace)
RUN git config --global --add safe.directory /workspace

#-- Unset SUID bits
RUN chmod u-s /usr/bin/mount /usr/bin/umount /usr/bin/chsh \
    /usr/bin/chfn /usr/bin/gpasswd /usr/bin/newgrp /usr/bin/passwd

#workspace
RUN mkdir -p /workspace
RUN . /sandbox/user/sb-login.env && chown $SB_LOGIN_USER_NAME:$SB_LOGIN_GROUP_NAME /workspace

########## SDK / Dev Tools and Dependencies Install

#yq
RUN wget https://github.com/mikefarah/yq/releases/download/v4.2.0/yq_linux_amd64 -O /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

# gcloud SDK
COPY gcloud-sdk-install.sh /tmp
RUN /tmp/gcloud-sdk-install.sh

# GitHub CLI
COPY dotnet-sdk-install.sh /tmp
RUN /tmp/dotnet-sdk-install.sh

# dotnet SDK
COPY gh-cli-install.sh /tmp
RUN /tmp/gh-cli-install.sh

#python build deps
RUN apt install -y make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev curl git libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

#########

#entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

#-- .bashrc - user
COPY dot-bashrc-init /tmp/.bashrc 
RUN . /sandbox/user/sb-login.env \
    && mv -f /tmp/.bashrc $SB_LOGIN_USER_HOME \
    && chown $SB_LOGIN_USER_NAME:$SB_LOGIN_GROUP_NAME $SB_LOGIN_USER_HOME/.bashrc


#-- .bashrc - root
RUN . /sandbox/user/sb-login.env \
    && cp -f $SB_LOGIN_USER_HOME/.bashrc ~/.bashrc

#apt cleanup
RUN apt-get clean && rm -rf /var/lib/apt/lists/*
    
#default- this is typically overwritten in the docker-compose.yml
WORKDIR /workspace/

ENV SHELL=/bin/bash
ENV EDITOR=nano
ENV VISUAL=nano
ENV TERM=xterm-256color

ENTRYPOINT [ "/entrypoint.sh" ]
