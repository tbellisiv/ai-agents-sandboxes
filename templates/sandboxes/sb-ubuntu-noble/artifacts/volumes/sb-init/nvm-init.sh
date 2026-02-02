#!/bin/bash

SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)

command -v nvm &> /dev/null
if [ $? -ne 0 ]; then

  NVM_VERSION=v0.40.3
  NODE_VERSION=v24.12.0

  echo ""
  echo "$SCRIPT_NAME: Installing nvm ($NVM_VERSION) and node ($NODE_VERSION)"
  echo ""

  curl -s -o- https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | bash
  if [ $? -ne 0 ]; then
    echo "$SCRIPT_NAME: Aborting setup- nvm install failed"
    exit 1
  fi

  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

  nvm install $NODE_VERSION
  if [ $? -ne 0 ]; then
    echo "$SCRIPT_NAME: Aborting setup- node install failed"
    exit 1
  fi

  # corepack install
  npm install -g corepack
  if [ $? -ne 0 ]; then
    echo "$SCRIPT_NAME: Aborting setup- corepack install failed"
    exit 1
  fi

  #-- pnpm install (packageManager in package.json)
  corepack enable
    if [ $? -ne 0 ]; then
    echo "$SCRIPT_NAME: Aborting setup- corepack enable failed"
    exit 1
  fi

  # add nvm to .bashrc
  cat <<EOF >>$HOME/.bashrc
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
nvm use $NODE_VERSION
EOF

  echo ""
  echo "$SCRIPT_NAME: nvm/node install complete"
  echo ""

fi
