# Shell behavior, plugins, and tool integrations.

(( $+functions[zinit] )) && zinit ice depth=1

# This is the advised way for loading completions.
# For a list of available completion plugins, see
# https://github.com/ohmyzsh/ohmyzsh/wiki/plugins

dotfiles_zinit_snippet OMZP::git
dotfiles_zinit_snippet OMZP::sudo
dotfiles_zinit_snippet OMZP::archlinux
dotfiles_zinit_snippet OMZP::kubectl
dotfiles_zinit_snippet OMZP::kubectx
dotfiles_zinit_snippet OMZP::docker
dotfiles_zinit_snippet OMZP::docker-compose
dotfiles_zinit_snippet OMZP::brew
# Let NVM own version selection, command priority, completion and hooks.
dotfiles_zinit_snippet OMZP::nvm
dotfiles_zinit_snippet OMZP::colorize
dotfiles_zinit_snippet OMZP::python
dotfiles_zinit_snippet OMZP::pip
dotfiles_zinit_snippet OMZP::rust
dotfiles_zinit_snippet OMZP::ssh
dotfiles_zinit_snippet OMZP::vscode
dotfiles_zinit_snippet OMZP::poetry
dotfiles_zinit_snippet OMZP::npm
dotfiles_zinit_snippet OMZP::ansible
dotfiles_zinit_snippet OMZP::jj
########################## >>>>> Dotenv
# Set plugin to auto load .env files and don't ask
export ZSH_DOTENV_PROMPT=false

# Plugin
dotfiles_zinit_snippet OMZP::dotenv
########################### <<<<< Dotenv

dotfiles_zinit_snippet OMZP::git-extras

if has thefuck; then
  dotfiles_zinit_snippet OMZP::thefuck
fi

if has fzf || [[ -d "${FZF_BASE:-}" ]] || [[ -d "$HOME/.fzf" ]] || [[ -d "/opt/homebrew/opt/fzf" ]] || [[ -d "/usr/local/opt/fzf" ]]; then
  dotfiles_zinit_snippet OMZP::fzf
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
