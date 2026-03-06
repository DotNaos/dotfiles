# Global aliases.

alias cls='clear'
alias c='clear'
alias clipboard='pbcopy'
alias ls='ls --color=auto'
alias gtree='git ls-tree -r --name-only HEAD | tree --fromfile'
alias docker-killall='docker stop $(docker ps -a -q)'
alias docker-removeall='docker rm $(docker ps -a -q)'
alias code='code-insiders'
alias uijj='lazyjj'
alias wt='worktree'

safe_source "${ZDOTDIR:-$HOME}/.zsh_aliases"
