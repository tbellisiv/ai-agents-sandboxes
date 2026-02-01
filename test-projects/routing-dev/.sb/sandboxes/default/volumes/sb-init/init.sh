#!/bin/bash

SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)

init_status=0

# ----- Init: nvm/node ------
$SCRIPT_DIR/nvm-init.sh
nvm_init_status=$?

# ----- Init: Claude
$SCRIPT_DIR/claude-init.sh
claude_init_status=$?

echo ""
if [ $nvm_init_status -ne 0 ]; then
  init_status=1
  echo "$SCRIPT_NAME: Warning- nvm/node initialization failed"
  echo ""
fi
if [ $claude_init_status -ne 0 ]; then
  init_status=1
  echo "$SCRIPT_NAME: Warning- Claude initialization failed"
  echo ""
fi

if [ $init_status -ne 0 ]; then
  echo "$SCRIPT_NAME: Sandbox initialization completed with error(s)"
  echo ""
  echo "$SCRIPT_NAME: Run 'sb logs ${SB_SANDBOX_ID}' to view logs"
else
  echo "$SCRIPT_NAME: Sandbox initialization successful"
  echo ""
  echo "$SCRIPT_NAME: Run 'sb shell ${SB_SANDBOX_ID}' to start a shell session"
fi

echo ""


