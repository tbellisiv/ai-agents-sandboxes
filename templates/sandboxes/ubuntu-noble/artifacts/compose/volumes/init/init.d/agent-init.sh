#/bin/bash

#Need to prevent CC from prompting to authenticate- even though CLAUDE_CODE_OAUTH_TOKEN/ANTHROPIC_API_KEY is defined
if [[ (-n $CLAUDE_CODE_OAUTH_TOKEN || -n $ANTHROPIC_API_KEY=) && ! -f HOME/.claude.json ]]; then
    echo '{"hasCompletedOnboarding": true}' > /$HOME/.claude.json
fi

#Install CC
which claude >/dev/null
if [ $? -ne 0 ]; then
    curl -fsSL https://claude.ai/install.sh | bash
else
    echo "$(claude --version) installed"
fi

