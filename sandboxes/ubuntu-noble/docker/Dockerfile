FROM ubuntu:noble-20260113

#-- Build args
ARG SB_ARG_SUHASH
ARG SB_ARG_TZ
ARG SB_ARG_USERNAME

ENV TZ="$SB_ARG_TZ"

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
RUN /create_user.sh ${SB_ARG_USERNAME}


#-- pnpm global packages (installed in post-create.sh, stored in packages volume)
ENV PNPM_HOME=/workspace/main/.devcontainer-stores/packages/pnpm-global
ENV PATH=$PATH:$PNPM_HOME


### SYSTEM CONFIG ###

#-- Git safe.directory (allows git in mounted workspace)
RUN git config --global --add safe.directory /workspace

#-- Persist bash history (dx: config in .devcontainer/.bashrc)
RUN mkdir /commandhistory && \
    touch /commandhistory/.bash_history && \
    chown -R ${SB_ARG_USERNAME} /commandhistory

#-- Create workspace and agent config directories
RUN mkdir -p /workspace /home/${SB_ARG_USERNAME}/.claude && \
    mkdir -p /home/${SB_ARG_USERNAME}/.gemini && \
    chown -R ${SB_ARG_USERNAME}:${SB_ARG_USERNAME} /home/${SB_ARG_USERNAME}/.claude && \
    chown -R ${SB_ARG_USERNAME}:${SB_ARG_USERNAME} /home/${SB_ARG_USERNAME}/.gemini

#apt cleanup
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

#-- Unset SUID bits
RUN chmod u-s /usr/bin/mount /usr/bin/umount /usr/bin/chsh \
    /usr/bin/chfn /usr/bin/gpasswd /usr/bin/newgrp /usr/bin/passwd

#workspace
RUN mkdir -p /workspace
RUN chown ${SB_ARG_USERNAME}:${SB_ARG_USERNAME} /workspace

#entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

#-- bash config
COPY .bashrc /home/${SB_ARG_USERNAME}/.bashrc
RUN chown ${SB_ARG_USERNAME}:${SB_ARG_USERNAME} /home/${SB_ARG_USERNAME}/.bashrc

### SWITCH TO NORMAL USER ###

USER ${SB_ARG_USERNAME}

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
