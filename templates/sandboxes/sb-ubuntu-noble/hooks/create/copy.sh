#! /bin/bash

set -e 

SCRIPT_DIR=$(readlink -f $(dirname $0))
SCRIPT_NAME=$(basename $0)

TEMPLATE_DIR=$(readlink -f $SCRIPT_DIR/../..)
TEMPLATE_ID=$(basename $TEMPLATE_DIR)
TEMPLATE_OPERATION=$(basename $SCRIPT_DIR)
TEMPLATE_HOOK=$(basename $SCRIPT_NAME ".sh")

SCRIPT_MSG_PREFIX="[template=$TEMPLATE_ID operation=$TEMPLATE_OPERATION hook=$TEMPLATE_HOOK]"

new_sandbox_path=$1

template_artifacts_path=$TEMPLATE_DIR/artifacts
if [ ! -d "${template_artifacts_path}" ]; then
  echo "${SCRIPT_MSG_PREFIX}: Error: Template artifacts directory '$template_artifacts_path' does not exist"
fi

cp -r -f $template_artifacts_path/* $new_sandbox_path

