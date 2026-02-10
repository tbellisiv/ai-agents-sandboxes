#! /bin/bash

SCRIPT_DIR=$(readlink -f $(dirname $0))
SCRIPT_NAME=$(basename $0)

MODULE_DIR=$(readlink -f $SCRIPT_DIR/../..)
MODULE_NAME=$(basename $MODULE_DIR)
MODULE_HOOK=$(basename $SCRIPT_NAME ".sh")

ARTIFACTS_DIR=$MODULE_DIR/artifacts

# Add 'echo' the commands that should be executed during a bash login (i.e. executed in the context of sourcing ~/.bashrc) 

# Examples:
#
# Set an env variable:
# echo 'export MY_ENV_VAR="some-value"''
#
# Source a .env file in the module:
# echo "source $ARTIFACTS_DIR/my-env-file.env"
#
# Run a script in the module:
# echo "$ARTIFACTS_DIR/my-script.sh"
#

SCRIPT_MSG_PREFIX="[module=$MODULE_NAME hook=$MODULE_HOOK]"

exit 0
