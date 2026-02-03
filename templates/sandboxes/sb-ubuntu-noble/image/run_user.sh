#!/bin/bash

#!/bin/bash

SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)

CONTEXT_DIR=$SCRIPT_DIR/docker
IMAGE_TAG=sb-ubuntu-noble

docker run -it --rm --name "${IMAGE_TAG}-local" -u 1000:1000 $IMAGE_TAG /bin/bash

