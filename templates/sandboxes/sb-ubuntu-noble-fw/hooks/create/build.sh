#!/bin/bash

SCRIPT_DIR=$(readlink -f $(dirname $0))
SCRIPT_NAME=$(basename $0)

TEMPLATE_DIR=$(readlink -f $SCRIPT_DIR/../..)
TEMPLATE_ID=$(basename $TEMPLATE_DIR)
TEMPLATE_OPERATION=$(basename $SCRIPT_DIR)
TEMPLATE_HOOK=$(basename $SCRIPT_NAME ".sh")

SCRIPT_MSG_PREFIX="[template=$TEMPLATE_ID operation=$TEMPLATE_OPERATION hook=$TEMPLATE_HOOK]"

if [ -z "$1" ]; then
  echo "${SCRIPT_MSG_PREFIX}: Usage $SCRIPT_NAME <new-sandbox-path>"
  exit 1
fi

echo "${SCRIPT_MSG_PREFIX}: Building/refreshing image"

new_sandbox_path=$1

template_image_path=$TEMPLATE_DIR/image
if [ ! -d "${template_image_path}" ]; then
  echo "${SCRIPT_MSG_PREFIX}: Error: Template image directory '$template_image_path' does not exist"
  exit 1
fi

# Build the image (build.sh handles building parent image first)
$template_image_path/build.sh
if [ $? -ne 0 ]; then
  echo "${SCRIPT_MSG_PREFIX}: Error- failed to build container image"
  exit 1
fi

echo "${SCRIPT_MSG_PREFIX}: Image build/refresh complete"
