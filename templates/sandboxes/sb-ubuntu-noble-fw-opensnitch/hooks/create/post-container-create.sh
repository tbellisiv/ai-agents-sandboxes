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

# Copy this template's sandbox artifacts into the running container (overlay parent's artifacts)
new_sandbox_compose_env_path=$new_sandbox_path/sb-compose.env
if [ ! -f "$new_sandbox_compose_env_path" ]; then
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
