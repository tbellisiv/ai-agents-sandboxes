#!/bin/bash

TOKEN="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"

docker run -it --rm -e "CLAUDE_CODE_OAUTH_TOKEN=$TOKEN" --name dev-sandbox dev-sandbox /bin/bash
