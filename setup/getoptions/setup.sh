#!/bin/bash

SCRIPT_NAME=$(basename $0)
SCRIPT_DIR=$(dirname $0)

SETUP_DIR=$SCRIPT_DIR
BIN_INSTALL_DIR=$SCRIPT_DIR/../../bin
LIB_INSTALL_DIR=$SCRIPT_DIR/../../lib

GETOPTIONS_RELEASES_URL=https://github.com/ko1nksm/getoptions/releases
GETOPTIONS_VERSION=v3.3.2

GETOPTIONS_DOWNLOAD_PATH=$SETUP_DIR/getoptions
GENGETOPTIONS_DOWNLOAD_PATH=$SETUP_DIR/gengetoptions

GETOPTIONS_BIN_INSTALL_PATH=$BIN_INSTALL_DIR/getoptions
GETOPTIONS_LIB_INSTALL_PATH=$LIB_INSTALL_DIR/getoptions_lib

if [ -f "$GETOPTIONS_DOWNLOAD_PATH" ]; then
    echo "$SCRIPT_NAME: Aborting setup- 'getoptions' command download path '$GETOPTIONS_DOWNLOAD_PATH' exists"
    exit 1
fi

# if [ -f "$GETOPTIONS_BIN_INSTALL_PATH" ]; then
#     echo "$SCRIPT_NAME: Aborting setup- getoptions' command install path $GETOPTIONS_BIN_INSTALL_PATH exists"
#     exit 1
# fi

if [ -f "$GENGETOPTIONS_DOWNLOAD_PATH" ]; then
    echo "$SCRIPT_NAME: Aborting setup- 'gengetoptions' command download path '$GENGETOPTIONS_DOWNLOAD_PATH' exists"
    exit 1
fi

if [ -f "$GETOPTIONS_LIB_INSTALL_PATH" ]; then
    echo "$SCRIPT_NAME: Aborting setup- 'getoptions' library install path $GETOPTIONS_LIB_INSTALL_PATH exists"
    exit 1
fi

echo "$SCRIPT_NAME: Downloading 'getoptions' ($GETOPTIONS_VERSION)"
curl -s -L -o $GETOPTIONS_DOWNLOAD_PATH "$GETOPTIONS_RELEASES_URL/download/$GETOPTIONS_VERSION/getoptions"
if [ $? -ne 0 ]; then
    echo "$SCRIPT_NAME: Aborting- download failed"
    exit 1
fi

# echo "$SCRIPT_NAME: Installing 'getoptions' ($GETOPTIONS_VERSION) command to $GETOPTIONS_BIN_INSTALL_PATH"
# cp -f $GETOPTIONS_DOWNLOAD_PATH $GETOPTIONS_BIN_INSTALL_PATH

# if [ $? -ne 0 ]; then
#     echo "$SCRIPT_NAME: Aborting- install failed"
#     exit 1
# fi

echo "$SCRIPT_NAME: Downloading 'gengetoptions' ($GETOPTIONS_VERSION)"
curl -s -L -o $GENGETOPTIONS_DOWNLOAD_PATH "$GETOPTIONS_RELEASES_URL/download/$GETOPTIONS_VERSION/gengetoptions"
if [ $? -ne 0 ]; then
    echo "$SCRIPT_NAME: Aborting- download failed"
    exit 1
fi

echo "$SCRIPT_NAME: Installing 'getoptions' ($GETOPTIONS_VERSION) library to $GETOPTIONS_LIB_INSTALL_PATH"
chmod 755 $GETOPTIONS_DOWNLOAD_PATH
chmod 755 $GENGETOPTIONS_DOWNLOAD_PATH
$GENGETOPTIONS_DOWNLOAD_PATH library > $GETOPTIONS_LIB_INSTALL_PATH
if [ $? -ne 0 ]; then
    echo "$SCRIPT_NAME: Aborting- install failed"
    exit 1
fi


