FROM ubuntu:noble-20260113

#-- Build args
ARG CLAUDE_CODE_VERSION=latest
ARG GEMINI_CLI_VERSION=latest
ARG OPENSNITCH_VERSION=1.7.2
ARG GO_VERSION=1.25.5
ARG TZ
ENV TZ="$TZ"

ARG USERNAME=sandbox

#-- System
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    ca-certificates \
    fzf \
    git \
    curl \
    iptables \
    jq \
    less \
    nano \
    nftables \
    procps \
    sudo \
#    tmux \
    unzip \
    vim \
    wget \
    # required to compile opensnitch-controller:
    protobuf-compiler

#create user
COPY create_user.sh  /
RUN /create_user.sh ${USERNAME}

#-- Disable npm
RUN echo '#!/bin/sh\necho "ERROR: npm is disabled in this devcontainer. Use pnpm instead."\nexit 1' > /usr/local/bin/npm && \
    chmod +x /usr/local/bin/npm

### SYSTEM CONFIG ###

#-- Git safe.directory (allows git in mounted workspace)
RUN git config --global --add safe.directory /workspace

#-- Persist bash history (dx: config in .devcontainer/.bashrc)
RUN mkdir /commandhistory && \
    touch /commandhistory/.bash_history && \
    chown -R ${USERNAME} /commandhistory

#-- Create workspace and config directories
RUN mkdir -p /workspace /home/${USERNAME}/.claude /home/${USERNAME}/.gemini && \
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.claude /home/${USERNAME}/.gemini

RUN apt-get clean && rm -rf /var/lib/apt/lists/*

#-- Unset SUID bits
RUN chmod u-s /usr/bin/mount /usr/bin/umount /usr/bin/chsh \
    /usr/bin/chfn /usr/bin/gpasswd /usr/bin/newgrp /usr/bin/passwd

#workspace
RUN mkdir -p /workspace
RUN chown ${USERNAME}:${USERNAME} /workspace

#entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

#-- bash config
COPY .bashrc /home/${USERNAME}/.bashrc
RUN chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.bashrc

### SWITCH TO NORMAL USER ###

USER ${USERNAME}

#nvm install
COPY node_setup.sh  /
RUN /node_setup.sh

#Need to prevent CC from prompting to authenticate- even though CLAUDE_CODE_OAUTH_TOKEN env var is populated
RUN echo '{"hasCompletedOnboarding": true}' > /$HOME/.claude.json

#Install CC
RUN curl -fsSL https://claude.ai/install.sh | bash

WORKDIR /workspace

ENV SHELL=/bin/bash
ENV EDITOR=nano
ENV VISUAL=nano
ENV TERM=xterm-256color


ENTRYPOINT [ "/entrypoint.sh" ]
