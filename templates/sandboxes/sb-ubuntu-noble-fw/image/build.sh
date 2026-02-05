#!/bin/bash

SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)

CONTEXT_DIR=$SCRIPT_DIR/docker
IMAGE_TAG=sb-ubuntu-noble-fw

TEMPLATE_DIR=$(readlink -f "$SCRIPT_DIR/..")
TEMPLATE_ID=$(basename $TEMPLATE_DIR)

SCRIPT_MSG_PREFIX="[template=$TEMPLATE_ID] $SCRIPT_NAME"

# Parent template reference
PARENT_TEMPLATE_ID="sb-ubuntu-noble"
PARENT_TEMPLATE_DIR=$(readlink -f "$TEMPLATE_DIR/../$PARENT_TEMPLATE_ID")

# First build the parent image
echo "$SCRIPT_MSG_PREFIX: Building parent image ($PARENT_TEMPLATE_ID)"
$PARENT_TEMPLATE_DIR/image/build.sh
if [ $? -ne 0 ]; then
  echo "$SCRIPT_MSG_PREFIX: Aborting- failed to build parent image"
  exit 1
fi

echo "$SCRIPT_MSG_PREFIX: Building image ($IMAGE_TAG)"
docker build $CONTEXT_DIR -t $IMAGE_TAG "$@"
if [ $? -ne 0 ]; then
  echo "$SCRIPT_MSG_PREFIX: Error- failed to build image"
  exit 1
fi

echo "$SCRIPT_MSG_PREFIX: Image build complete"
