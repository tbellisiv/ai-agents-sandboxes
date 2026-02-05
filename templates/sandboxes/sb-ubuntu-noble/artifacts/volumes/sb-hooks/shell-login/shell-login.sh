#!/bin/bash

SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)

modules_login_status=0

# ----- Shell Login: Module Hooks ------
$SCRIPT_DIR/module-hooks-shell-login.sh
modules_login_status=$?

if [ $modules_login_status -ne 0 ]; then
  init_status=1
  echo "$SCRIPT_NAME: Warning- One or more shell login module hooks failed"
  echo ""
fi


