# Shell behavior, plugins, and tool integrations.

zinit ice depth=1

# This is the advised way for loading completions.
# For a list of available completion plugins, see
# https://github.com/ohmyzsh/ohmyzsh/wiki/plugins

zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::archlinux
zinit snippet OMZP::kubectl
zinit snippet OMZP::kubectx
zinit snippet OMZP::docker
zinit snippet OMZP::docker-compose
zinit snippet OMZP::brew
zinit snippet OMZP::nvm
zinit snippet OMZP::colorize
zinit snippet OMZP::python
zinit snippet OMZP::pip
zinit snippet OMZP::rust
zinit snippet OMZP::ssh
zinit snippet OMZP::vscode
zinit snippet OMZP::poetry
zinit snippet OMZP::npm
zinit snippet OMZP::ansible
zinit snippet OMZP::jj
########################## >>>>> Dotenv
# Set plugin to auto load .env files and don't ask
export ZSH_DOTENV_PROMPT=false

# Plugin
zinit snippet OMZP::dotenv
########################### <<<<< Dotenv

zinit snippet OMZP::git-extras

if has thefuck; then
  zinit snippet OMZP::thefuck
fi

if has fzf || [[ -d "${FZF_BASE:-}" ]] || [[ -d "$HOME/.fzf" ]] || [[ -d "/opt/homebrew/opt/fzf" ]] || [[ -d "/usr/local/opt/fzf" ]]; then
  zinit snippet OMZP::fzf
fi
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

if has rbenv; then
  eval "$(rbenv init - zsh)"
fi
