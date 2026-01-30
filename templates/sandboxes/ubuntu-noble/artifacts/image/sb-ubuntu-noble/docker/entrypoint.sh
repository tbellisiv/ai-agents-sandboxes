#!/bin/bash

if [ -z "$@" ]; then
    echo "sleep infinity"
    exec sleep infinity
else
    echo "$@"
    exec "$@"   
fi
