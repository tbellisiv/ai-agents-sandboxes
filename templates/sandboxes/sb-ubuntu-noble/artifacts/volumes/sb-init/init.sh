#!/bin/bash

SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)

# ----- Init: nvm/node ------
$SCRIPT_DIR/nvm-init.sh

# ----- Init: Claude
$SCRIPT_DIR/claude-init.sh

