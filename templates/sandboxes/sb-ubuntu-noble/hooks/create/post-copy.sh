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

echo "${SCRIPT_MSG_PREFIX}: Executing post-copy steps"

new_sandbox_path=$1

if [ ! -d $new_sandbox_path ]; then
  echo "${SCRIPT_MSG_PREFIX}: Error: Sandbox directory '$new_sandbox_path' does not exist"
  exit 1
fi

new_sandbox_env_path=$new_sandbox_path/sb-sandbox.env
if [ ! -f $new_sandbox_env_path ]; then
  echo "${SCRIPT_MSG_PREFIX}: Error: Sandbox env file '$new_sandbox_env_path' does not exist"
  exit 1
fi

source $new_sandbox_env_path

if [ -z "$SB_SANDBOX_IMAGE" ]; then
  echo "${SCRIPT_MSG_PREFIX}: Error: Variable 'SB_SANDBOX_IMAGE' is defined in sandbox env file '$new_sandbox_env_path'"
  exit 1
fi


#generate the sb-login.env

temp_container_name="temp-$RANDOM-$RANDOM"

docker create -q --name $temp_container_name $SB_SANDBOX_IMAGE
if [ $? -ne 0 ]; then
  echo "${SCRIPT_MSG_PREFIX}: Error- failed to create temporary container '$temp_container_name' from image '$SB_SANDBOX_IMAGE'"
  exit 1
fi

docker cp -q $temp_container_name:/sandbox/build/sb-login.env $new_sandbox_path/sb-login.env
if [ $? -ne 0 ]; then
  echo "${SCRIPT_MSG_PREFIX}: Error- failed to extract file '/sandbox/build/sb-login.env ' from temporary container '$temp_container_name'"
  exit 1
fi

docker rm $temp_container_name
if [ $? -ne 0 ]; then
  echo "${SCRIPT_MSG_PREFIX}: Warning- failed to remove from temporary container '$temp_container_name'"
fi

echo "${SCRIPT_MSG_PREFIX}: Post-copy steps completed"