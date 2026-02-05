#!/bin/bash

SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)

init_status=0

# ----- Init: SSH ------
$SCRIPT_DIR/ssh-init.sh
ssh_init=$?

# ----- Init: nuget ------
$SCRIPT_DIR/nuget-init.sh
nuget_init=$?

# ----- Init: nvm/node ------
$SCRIPT_DIR/nvm-init.sh
nvm_init_status=$?

# ----- Init: Claude
$SCRIPT_DIR/claude-init.sh
claude_init_status=$?

# ----- Init: modules ------
$SCRIPT_DIR/modules-init.sh
module_init=$?

# ----- Init: Firewall (LAST - after all network-dependent initialization) ------
$SCRIPT_DIR/firewall-init.sh
firewall_init=$?

echo ""
if [ $nuget_init -ne 0 ]; then
  init_status=1
  echo "$SCRIPT_NAME: Warning- NuGet initialization failed"
  echo ""
fi
if [ $ssh_init -ne 0 ]; then
  init_status=1
  echo "$SCRIPT_NAME: Warning- SSH initialization failed"
  echo ""
fi
if [ $module_init -ne 0 ]; then
  init_status=1
  echo "$SCRIPT_NAME: Warning- module initialization failed"
  echo ""
fi
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
if [ $firewall_init -ne 0 ]; then
  init_status=1
  echo "$SCRIPT_NAME: ERROR- Firewall initialization failed"
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
echo "sleep infinity"
exec sleep infinity
