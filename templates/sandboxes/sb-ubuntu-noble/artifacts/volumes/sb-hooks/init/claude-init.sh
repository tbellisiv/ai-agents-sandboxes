#!/bin/bash

SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)

#create symlink for $HOME/.claude to /sandbox/user/.claude
if [ ! -d "$HOME/.claude" ]; then
  echo "$SCRIPT_NAME: Creating symlink: $HOME/.claude --> /sandbox/user/.claude (volume mount)"
  mkdir -p /sandbox/user/.claude
  ln -s /sandbox/user/.claude "$HOME/.claude"
fi

#create empty json  and symlink for $HOME/.claude.json
if [ ! -f "$HOME/.claude.json" ]; then

  #initialize .claude.json if needed
  if [ ! -f /sandbox/user/.claude.json ]; then

    # If a CLAUDE OAUTH token or API Key is in the environment initialize claude.json to bypass prompting the user for authentication on initial claude execution
    if [[ -n "$CLAUDE_CODE_OAUTH_TOKEN" || -n "$ANTHROPIC_API_KEY" ]]; then
      echo "$SCRIPT_NAME: Initializing .claude.json: '{\"hasCompletedOnboarding\": true}'"
      echo '{"hasCompletedOnboarding": true}' > /sandbox/user/.claude.json
    else
      #create an empty JSON file
      echo "$SCRIPT_NAME: Initializing .claude.json: '{ }'"
      echo '{ }' > /sandbox/user/.claude.json
    fi

    #create the symlink
    echo "$SCRIPT_NAME: Creating symlink: $HOME/.claude.json --> /sandbox/user/.claude (volume mount)"
    ln -s /sandbox/user/.claude.json "$HOME/.claude.json"
  fi
fi


command -v claude &> /dev/null
if [ $? -ne 0 ]; then

  echo ""
  echo "$SCRIPT_NAME: Installing Claude"
  echo ""

  curl -fsSL https://claude.ai/install.sh | bash
  if [ $? -ne 0 ]; then
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
  if [ $? -ne 0 ]; then
    echo "$SCRIPT_NAME: Aborting- Claude update failed"
    exit 1
  fi

fi

