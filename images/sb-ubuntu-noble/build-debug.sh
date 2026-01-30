#!/bin/bash

SCRIPT_DIR=$(dirname $0)

CONTEXT_DIR=$SCRIPT_DIR/docker

IMAGE_TAG=sb-ubuntu-noble-debug

echo "docker build $CONTEXT_DIR -t $IMAGE_TAG --build-arg USER_ID=$(id -u) --build-arg GROUP_ID=$(id -g)"
docker build $CONTEXT_DIR -f $CONTEXT_DIR/Dockerfile-debug -t $IMAGE_TAG --build-arg USER_ID=$(id -u) --build-arg GROUP_ID=$(id -g) "$@"