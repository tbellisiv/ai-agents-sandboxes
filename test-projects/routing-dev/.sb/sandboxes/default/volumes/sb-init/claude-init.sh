#/bin/bash

SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)

#Need to prevent CC from prompting to authenticate- even though CLAUDE_CODE_OAUTH_TOKEN/ANTHROPIC_API_KEY is defined
if [[ (-n "$CLAUDE_CODE_OAUTH_TOKEN" || -n "$ANTHROPIC_API_KEY") && ! -f HOME/.claude.json ]]; then
    echo '{"hasCompletedOnboarding": true}' > /$HOME/.claude.json
fi

command -v claude &> /dev/null
if [ $? -ne 0 ]; then
  
  echo ""
  echo "$SCRIPT_NAME: Installing Claude"
  echo ""

  curl -fsSL https://claude.ai/install.sh | bash
  if [ $? -ne -0 ]; then
    echo "$SCRIPT_NAME: Aborting- Claude install failed"
    exit 1
  fi

  echo ""
  echo "$SCRIPT_NAME: Claude install complete"
  echo ""

else

  echo ""
  echo "$SCRIPT_NAME: Updating Claude"
  echo ""

  claude update
  if [ $? -ne -0 ]; then
    echo "$SCRIPT_NAME: Aborting- Claude update failed"
    exit 1
  fi

fi

