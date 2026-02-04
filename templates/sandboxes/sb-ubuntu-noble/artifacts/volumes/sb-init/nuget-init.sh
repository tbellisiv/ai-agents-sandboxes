#!/bin/bash

SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)

#create symlink for $HOME/.nuget to /sandbox/user-secrets/.nuget
if [ ! -d "$HOME/.nuget/NuGet " ]; then
  echo "$SCRIPT_NAME: Creating symlink: $HOME/.nuget/NuGet --> /sandbox/user-secrets/.nuget/NuGet  (volume mount)"
  mkdir -p /sandbox/user-secrets/.nuget/NuGet 
  if [ $? -ne 0 ]; then
    echo "$SCRIPT_NAME: Aborting- mkdir .nuget/NuGet failed"
    exit 1
  fi

  ln -s /sandbox/user-secrets/.nuget "$HOME/.nuget"
  if [ $? -ne 0 ]; then
    echo "$SCRIPT_NAME: Aborting- symlink creation failed"
    exit 1
  fi
fi

echo ""
echo "$SCRIPT_NAME: nuget init completed"
echo ""

