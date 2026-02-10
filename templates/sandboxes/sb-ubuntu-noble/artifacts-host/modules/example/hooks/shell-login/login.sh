#! /bin/bash

SCRIPT_DIR=$(readlink -f $(dirname $0))
SCRIPT_NAME=$(basename $0)

MODULE_DIR=$(readlink -f $SCRIPT_DIR/../..)
MODULE_NAME=$(basename $MODULE_DIR)
MODULE_HOOK=$(basename $SCRIPT_NAME ".sh")

ARTIFACTS_DIR=$MODULE_DIR/artifacts

SCRIPT_MSG_PREFIX="[module=$MODULE_NAME hook=$MODULE_HOOK]"

exit 0
