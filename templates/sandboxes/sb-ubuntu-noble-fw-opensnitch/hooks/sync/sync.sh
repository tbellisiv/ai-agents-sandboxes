#!/bin/bash

SCRIPT_DIR=$(readlink -f $(dirname $0))
SCRIPT_NAME=$(basename $0)

TEMPLATE_DIR=$(readlink -f $SCRIPT_DIR/../..)
TEMPLATE_ID=$(basename $TEMPLATE_DIR)
TEMPLATE_OPERATION=$(basename $SCRIPT_DIR)
TEMPLATE_HOOK=$(basename $SCRIPT_NAME ".sh")

SCRIPT_MSG_PREFIX="[template=$TEMPLATE_ID operation=$TEMPLATE_OPERATION hook=$TEMPLATE_HOOK]"

# Parent template reference
PARENT_TEMPLATE_ID="sb-ubuntu-noble"
PARENT_TEMPLATE_DIR=$(readlink -f $TEMPLATE_DIR/../$PARENT_TEMPLATE_ID)

if [ -z "$1" ]; then
  echo "${SCRIPT_MSG_PREFIX}: Usage $SCRIPT_NAME <sandbox-path>"
  exit 1
fi

sandbox_path=$1

# Execute parent hook
parent_hook="$PARENT_TEMPLATE_DIR/hooks/$TEMPLATE_OPERATION/$SCRIPT_NAME"
if [ -f "$parent_hook" ]; then
  echo "${SCRIPT_MSG_PREFIX}: Executing parent hook"
  $parent_hook "$sandbox_path"
  if [ $? -ne 0 ]; then
    echo "${SCRIPT_MSG_PREFIX}: Error- parent hook failed"
    exit 1
  fi
fi

# Build the image (handles building parent image first)
template_image_path=$TEMPLATE_DIR/image
if [ ! -d "${template_image_path}" ]; then
  echo "${SCRIPT_MSG_PREFIX}: Error: Template image directory '$template_image_path' does not exist"
  exit 1
fi

$template_image_path/build.sh
if [ $? -ne 0 ]; then
  echo "${SCRIPT_MSG_PREFIX}: Error- failed to build container image"
  exit 1
fi

echo "${SCRIPT_MSG_PREFIX}: Complete"
