#!/bin/bash

docker build . --build-arg TZ=UTC -t ai-agent-sandbox-local:ubuntu-noble