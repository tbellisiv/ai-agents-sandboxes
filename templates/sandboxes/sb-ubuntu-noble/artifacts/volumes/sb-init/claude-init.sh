#/bin/bash

SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)

#create symlink for $HOME/.claude to /sandbox/user/.claude
if [ ! -d "$HOME/.claude" ]; then
  echo "$SCRIPT_NAME: Creating symlink: $HOME/.claude --> /sandbox/user/.claude (volume mount)"
  mkdir -p /sandbox/user/.claude
  ln -s /sandbox/user/.claude "$HOME/.claude"
fi

#create empty file and symlink for $HOME/.claude.json
if [[ ! -f "$HOME/.claude.json" && ! -f /sandbox/user/.claude.json ]]; then
  echo "$SCRIPT_NAME: Creating symlink to empty file: sb $HOME/.claude.json --> /sandbox/user/.claude (volume mount)"
  touch /sandbox/user/.claude.json
  ln -s /sandbox/user/.claude.json "$HOME/.claude.json"
fi


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

