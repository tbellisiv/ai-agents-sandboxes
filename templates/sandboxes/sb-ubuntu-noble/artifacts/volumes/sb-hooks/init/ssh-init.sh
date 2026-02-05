#!/bin/bash

SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)

#create symlink for $HOME/.ssh to /sandbox/user-secrets/.ssh
if [ ! -d "$HOME/.ssh" ]; then
  echo "$SCRIPT_NAME: Creating symlink: $HOME/.ssh --> /sandbox/user-secrets/.ssh (volume mount)"
  mkdir -p /sandbox/user-secrets/.ssh
  if [ $? -ne 0 ]; then
    echo "$SCRIPT_NAME: Aborting- mkdir .ssh failed"
    exit 1
  fi
  
  chmod 700 /sandbox/user-secrets/.ssh
  if [ $? -ne 0 ]; then
    echo "$SCRIPT_NAME: Aborting- .ssh/ permissions change failed"
    exit 1
  fi

  ln -s /sandbox/user-secrets/.ssh "$HOME/.ssh"
  if [ $? -ne 0 ]; then
    echo "$SCRIPT_NAME: Aborting- symlink creation failed"
    exit 1
  fi
fi

echo ""
echo "$SCRIPT_NAME: ssh init completed"
echo ""

