eval "$(/opt/homebrew/bin/brew shellenv)"

# Zinit plugin directory
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if not already installed
if [ ! -d "${ZINIT_HOME}" ]; then
    echo "Zinit not found, installing..."
    mkdir -p "$(dirname $ZINIT_HOME)"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

zinit ice depth=1;

################ PROMPT ################
# ! >>>>>>>>> starship
eval "$(starship init zsh)"



# Realtime completion
zinit light marlonrichert/zsh-autocomplete

# Custom
zstyle '*:compinit' arguments -D -i -u -C -w
# zstyle ':autocomplete:*:*:exec:*' list-choices false


################ ZINIT PLUGINS ################
# Base
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

zinit light jeffreytse/zsh-vi-mode



# Add oh-my-zsh plugins
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::archlinux
zinit snippet OMZP::kubectl
zinit snippet OMZP::kubectx
zinit snippet OMZP::command-not-found
zinit snippet OMZP::docker
zinit snippet OMZP::brew
zinit snippet OMZP::nvm
zinit snippet OMZP::colorize

# Load completions
autoload -U compinit && compinit

zinit cdreplay -q

################ ZSTYLE ################
# Base
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

################ KEYBINDS ################
bindkey -e # Use emacs keybindings
bindkey '^[[B' history-search-forward
bindkey '^[[A' history-search-backward


################ HISTORY ################
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


################ ALIAS ################
alias cls='clear'
alias c='clear'
alias ls='ls --color=auto'
alias gtree='git ls-tree -r --name-only HEAD | tree --fromfile'

################ SHELL INTEGRATION ################
eval "$(fzf --zsh)"
eval "$(zoxide init --cmd cd zsh)"

eval "$(uv generate-shell-completion zsh)"
eval "$(uvx --generate-shell-completion zsh)"
eval
    fuck () {
        TF_PYTHONIOENCODING=$PYTHONIOENCODING;
        export TF_SHELL=zsh;
        export TF_ALIAS=fuck;
        TF_SHELL_ALIASES=$(alias);
        export TF_SHELL_ALIASES;
        TF_HISTORY="$(fc -ln -10)";
        export TF_HISTORY;
        export PYTHONIOENCODING=utf-8;
        TF_CMD=$(
            thefuck THEFUCK_ARGUMENT_PLACEHOLDER $@
        ) && eval $TF_CMD;
        unset TF_HISTORY;
        export PYTHONIOENCODING=$TF_PYTHONIOENCODING;
        test -n "$TF_CMD" && print -s $TF_CMD
    }




# pnpm
export PNPM_HOME="/Users/oli/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

export PATH="$PATH:/Users/oli/.modular/bin"

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/oli/.lmstudio/bin"

# Added by Windsurf
export PATH="/Users/oli/.codeium/windsurf/bin:$PATH"
export PATH="/Users/oli/.codeium/windsurf/bin:$PATH"

################ API KEYS ################
. "$HOME/.local/bin/env"
# API Keys (load from .env file)
if [ -f "$HOME/.env" ]; then
  export $(grep -v '^#' "$HOME/.env" | xargs)
fi
