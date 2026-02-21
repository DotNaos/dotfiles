# Shell behavior, plugins, and tool integrations.

zinit ice depth=1

zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::archlinux
zinit snippet OMZP::kubectl
zinit snippet OMZP::kubectx
zinit snippet OMZP::command-not-found
zinit snippet OMZP::docker
zinit snippet OMZP::docker-compose
zinit snippet OMZP::brew
zinit snippet OMZP::nvm
zinit snippet OMZP::colorize
zinit snippet OMZP::python
zinit snippet OMZP::pip
zinit snippet OMZP::rust
zinit snippet OMZP::ssh
zinit snippet OMZP::thefuck
zinit snippet OMZP::vscode
zinit snippet OMZP::poetry
zinit snippet OMZP::npm
zinit snippet OMZP::dotenv
zinit snippet OMZP::ansible
zinit snippet OMZP::1password
zinit snippet OMZP::jj

zinit cdreplay -q

bindkey -e
bindkey '^[[B' history-search-forward
bindkey '^[[A' history-search-backward

HISTSIZE=1000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUPE=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_ignore_dups
setopt hist_save_no_dups
setopt hist_find_no_dups

export DOTENV_ALWAYS_LOAD=1
export DOTENV_CONFIG_AUTO=1

safe_source "$HOME/.local/bin/env"

if [[ -f "$HOME/.env" ]]; then
  set -a
  source "$HOME/.env"
  set +a
fi

if has rbenv; then
  eval "$(rbenv init - zsh)"
fi
