#!/bin/bash

SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)

CONTEXT_DIR=$SCRIPT_DIR/docker
IMAGE_TAG=sb-ubuntu-noble

TEMPLATE_DIR=$(readlink -f "$SCRIPT_DIR/..")
TEMPLATE_ID=$(basename $TEMPLATE_DIR)

SCRIPT_MSG_PREFIX="[template=$TEMPLATE_ID] $SCRIPT_NAME"

INSTALL_BIN_ROOT=$(dirname $(which sb))
INSTALL_ROOT="$INSTALL_BIN_ROOT/.."
INSTALL_ENV_ROOT="$INSTALL_ROOT/env"

TEMPLATES_ENV_PATH=$(readlink -f "$INSTALL_ENV_ROOT/sb-templates.env")

if [ ! -f "$TEMPLATES_ENV_PATH" ]; then
  echo "$SCRIPT_MSG_PREFIX: Aborting- file '$TEMPLATES_ENV_PATH' does not exist"
  exit 1
fi

source $TEMPLATES_ENV_PATH

if [ -z "$SB_TEMPLATES_IMAGE_SU_HASH" ]; then
  echo "$SCRIPT_MSG_PREFIX: Aborting- SB_TEMPLATES_IMAGE_SU_HASH is not defined in file '$TEMPLATES_ENV_PATH'"
  exit 1
fi

if [ -z "$SB_TEMPLATES_IMAGE_USER_HASH" ]; then
  echo "$SCRIPT_MSG_PREFIX: Aborting- SB_TEMPLATES_IMAGE_USER_HASH is not defined in file '$TEMPLATES_ENV_PATH'"
  exit 1
fi

docker build $CONTEXT_DIR -t $IMAGE_TAG --build-arg "SU_HASH=$SB_TEMPLATES_IMAGE_SU_HASH" --build-arg "USER_HASH=$SB_TEMPLATES_IMAGE_USER_HASH" --build-arg USER_ID=$(id -u) --build-arg GROUP_ID=$(id -g) "$@"

