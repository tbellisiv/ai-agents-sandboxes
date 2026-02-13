#!/bin/bash

SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)

CONTEXT_DIR=$SCRIPT_DIR/docker
IMAGE_TAG=sb-ubuntu-noble-fw-opensnitch

docker run -it --rm --name "${IMAGE_TAG}-local" \
    --cap-add NET_ADMIN \
    --cap-add NET_RAW \
    --cap-add SETUID \
    --cap-add SETGID \
    --cap-add DAC_OVERRIDE \
    --cap-add CHOWN \
    $IMAGE_TAG /bin/bash
