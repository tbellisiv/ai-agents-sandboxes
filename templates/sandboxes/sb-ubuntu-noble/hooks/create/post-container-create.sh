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

echo "${SCRIPT_MSG_PREFIX}: Copying template artifacts - sandbox"

new_sandbox_path=$1

template_artifacts_path=$TEMPLATE_DIR/artifacts-sandbox
if [ ! -d "${template_artifacts_path}" ]; then
  echo "${SCRIPT_MSG_PREFIX}: Error: Template artifacts directory '$template_artifacts_path' does not exist"
  exit 1
fi

new_sandbox_compose_env_path=$new_sandbox_path/sb-compose.env
if [ ! -f $new_sandbox_compose_env_path ]; then
  echo "${SCRIPT_MSG_PREFIX}: Error: Sandbox env file '$new_sandbox_compose_env_path' does not exist"
  exit 1
fi

source $new_sandbox_compose_env_path
if [ -z "${SB_COMPOSE_SERVICE}" ]; then
  echo "${SCRIPT_MSG_PREFIX}: Error: Variable 'SB_COMPOSE_SERVICE' is not defined in file '$new_sandbox_compose_env_path'"
  exit 1
fi

compose_file_path=$new_sandbox_path/docker-compose.yml
if [ ! -f "${compose_file_path}" ]; then
  echo "${SCRIPT_MSG_PREFIX}: Error: Docker compose file '$compose_file_path' does not exist"
  exit 1
fi

echo "${SCRIPT_MSG_PREFIX}: Copying sandbox container artifacts: ${template_artifacts_path}/* --> ${SB_COMPOSE_SERVICE}:/"
echo "docker compose -f $compose_file_path cp $template_artifacts_path/. ${SB_COMPOSE_SERVICE}:/"
docker compose -f $compose_file_path cp $template_artifacts_path/. ${SB_COMPOSE_SERVICE}:/
if [ $? -ne 0 ]; then
  echo "${SCRIPT_MSG_PREFIX}: Error: Docker compose file copy failed"
  exit 1
fi

echo "${SCRIPT_MSG_PREFIX}: Template artifact copy complete - sandbox"

