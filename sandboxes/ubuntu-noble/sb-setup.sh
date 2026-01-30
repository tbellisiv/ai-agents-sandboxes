#! /bin/bash

set -e 

SB_PROFILE_IMAGE=sb-ubuntu-noble:latest

TEMP_CONTAINER_NAME="temp-$RANDOM-$RANDOM"

docker create --name $TEMP_CONTAINER_NAME $SB_PROFILE_IMAGE

docker cp $TEMP_CONTAINER_NAME:/sandbox/user/sb-user.env sb-user.env

docker rm $TEMP_CONTAINER_NAME
echo 