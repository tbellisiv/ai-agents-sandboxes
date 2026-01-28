
# persist history
export PROMPT_COMMAND="history -a"
export HISTFILE=/commandhistory/.bash_history
export HISTSIZE=10000
export HISTFILESIZE=20000

# shell prompt
export PS1="\[\033[90m\]\u\[\033[00m\] \[\033[32m\]\w\[\033[00m\] "

# aliases
alias p="pnpm"
alias g="git"
alias ll="ls -la"

# FZF keybindings
[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash

#NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
nvm use $NODE_VERSION

export PATH=$HOME/.local/bin:$PATH
