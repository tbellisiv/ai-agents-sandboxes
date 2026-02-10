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

echo "${SCRIPT_MSG_PREFIX}: Copying template artifacts"

new_sandbox_path=$1

template_artifacts_path=$TEMPLATE_DIR/artifacts
if [ ! -d "${template_artifacts_path}" ]; then
  echo "${SCRIPT_MSG_PREFIX}: Error: Template artifacts directory '$template_artifacts_path' does not exist"
fi

cp -r -f $template_artifacts_path/* $new_sandbox_path

new_sandbox_compose_env_path=$new_sandbox_path/sb-compose.env

#sb-compose.env: Prepend SB_COMPOSE_ROOT to sb-compose.env
sed -i "1i SB_COMPOSE_ROOT=$new_sandbox_path" $new_sandbox_compose_env_path

#sb-compose.env: Replace all references to '__SB_COMPOSE_ROOT__' with $SB_COMPOSE_ROOT
sed -i "s#__SB_COMPOSE_ROOT__#$new_sandbox_path#g" $new_sandbox_compose_env_path

#sb-compose.env: Replace all references to '__SB_COMPOSE_VOLUMES_ROOT__' with $new_sandbox_path/volumes
sed -i "s#__SB_COMPOSE_VOLUMES_ROOT__#$new_sandbox_path/volumes#g" $new_sandbox_compose_env_path

#sb-sandbox.env: Appended module search path
echo "SB_MODULE_SEARCH_PATH=\"$new_sandbox_path/modules\"" >> $new_sandbox_path/sb-sandbox.env

echo "${SCRIPT_MSG_PREFIX}: Template artifact copy complete"

