#! /bin/bash

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

echo "${SCRIPT_MSG_PREFIX}: Copying template artifacts - host"

new_sandbox_path=$1

template_artifacts_path=$TEMPLATE_DIR/artifacts-host
if [ ! -d "${template_artifacts_path}" ]; then
  echo "${SCRIPT_MSG_PREFIX}: Error: Template artifacts directory '$template_artifacts_path' does not exist"
  exit 1
fi

cp -r -f $template_artifacts_path/* $new_sandbox_path
if [ $? -ne 0 ]; then
  echo "${SCRIPT_MSG_PREFIX}: Error: Template artifacts copy failed"
  exit 1
fi

#sb-sandbox.env: Appended module search path
echo "SB_MODULE_SEARCH_PATH=\"$new_sandbox_path/modules\"" >> $new_sandbox_path/sb-sandbox.env

echo "${SCRIPT_MSG_PREFIX}: Template artifact copy complete - host"

