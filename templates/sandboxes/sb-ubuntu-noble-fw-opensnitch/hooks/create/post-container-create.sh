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
  echo "${SCRIPT_MSG_PREFIX}: Usage $SCRIPT_NAME <new-sandbox-path>"
  exit 1
fi

new_sandbox_path=$1

# Execute parent hook first (copies all base artifacts)
echo "${SCRIPT_MSG_PREFIX}: Copying parent template artifacts - sandbox"
parent_hook="$PARENT_TEMPLATE_DIR/hooks/$TEMPLATE_OPERATION/$SCRIPT_NAME"
if [ -f "$parent_hook" ]; then
  echo "${SCRIPT_MSG_PREFIX}: Executing parent hook"
  $parent_hook "$new_sandbox_path"
  if [ $? -ne 0 ]; then
    echo "${SCRIPT_MSG_PREFIX}: Error- parent hook failed"
    exit 1
  fi
fi

# Overlay this template's artifacts over the parent template's artifacts
echo "${SCRIPT_MSG_PREFIX}: Copying template artifacts - sandbox"

template_artifacts_path=$TEMPLATE_DIR/artifacts-sandbox
if [ ! -d "${template_artifacts_path}" ]; then
  echo "${SCRIPT_MSG_PREFIX}: Error: Template artifacts directory '$template_artifacts_path' does not exist"
  exit 1
fi

#There are no artifacts to overlay currently
#cp -r -f $template_artifacts_path/* $new_sandbox_path

echo "${SCRIPT_MSG_PREFIX}: Template artifact copy complete - sandbox"
