#!/bin/bash

SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)

INIT_SCRIPT_PATH=/sandbox/init/init.sh

if [ -z "$@" ]; then
  if [ -f "$INIT_SCRIPT_PATH" ]; then
    echo "$SCRIPT_NAME: Executing sandbox init script: $INIT_SCRIPT_PATH"
    echo ""
    $INIT_SCRIPT_PATH
    if [ $? -ne 0 ]; then
      echo "$SCRIPT_NAME: WARNING: Sandbox initialization failed"
    fi
  fi
  echo "sleep infinity"
  exec sleep infinity
else
  echo "$@"
  exec "$@"   
fi
