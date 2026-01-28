#!/bin/bash

docker run -it --rm --name ubuntu-noble --env 'TZ=UTC' ubuntu:noble-20260113 /bin/bash
