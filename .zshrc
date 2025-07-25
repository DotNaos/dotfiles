# Initialize brew environment (supports both macOS Homebrew and Linux Linuxbrew)
if [[ -f "/opt/homebrew/bin/brew" ]]; then
    # macOS Homebrew (Apple Silicon)
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f "/usr/local/bin/brew" ]]; then
    # macOS Homebrew (Intel) or Linux system-wide
    eval "$(/usr/local/bin/brew shellenv)"
elif [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
    # Linux Linuxbrew (system-wide)
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [[ -f "$HOME/.linuxbrew/bin/brew" ]]; then
    # Linux Linuxbrew (user-specific)
    eval "$($HOME/.linuxbrew/bin/brew shellenv)"
fi
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

################ ZSTYLE ################
# Base
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:*' path-expand false

################ ZINIT PLUGINS ################
# Base
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# Custom
#zinit light marlonrichert/zsh-autocomplete
#zinit light jeffreytse/zsh-vi-mode

# Add oh-my-zsh plugins
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
# zinit snippet OMZP::macos
zinit snippet OMZP::dotenv
zinit snippet OMZP::ansible
zinit snippet OMZP::1password

# Load completions
autoload -U compinit && compinit

zinit cdreplay -q


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
alias docker-killall='docker stop $(docker ps -a -q)'
alias docker-removeall='docker rm $(docker ps -a -q)'

################ API KEYS ################
# Load local environment if available
if [ -f "$HOME/.local/bin/env" ]; then
    . "$HOME/.local/bin/env"
fi

# API Keys (load from .env file)
if [ -f "$HOME/.env" ]; then
  export $(grep -v '^#' "$HOME/.env" | xargs)
fi

################ PATH CONFIGURATION ################
# Function to add to PATH only if not already present
add_to_path() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) export PATH="$1:$PATH" ;;
    esac
}

# Add various tools to PATH
add_to_path "$HOME/Library/pnpm"
add_to_path "/opt/homebrew/opt/libpq/bin"
add_to_path "$HOME/.modular/bin"
add_to_path "$HOME/.lmstudio/bin"
add_to_path "$HOME/.codeium/windsurf/bin"
add_to_path "$HOME/.dotnet/tools"

################ SHELL INTEGRATION ################
eval "$(fzf --zsh)"
eval "$(zoxide init --cmd cd zsh)"
eval "$(uv generate-shell-completion zsh)"
eval "$(uvx --generate-shell-completion zsh)"

# thefuck integration
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

# pnpm: TODO: FIX THIS
export PNPM_HOME="/home/oli/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

eval "$(rbenv init - zsh)"

# In ~/.zshrc  (oder ~/.bashrc)
if [[ "$TERM" == "xterm-ghostty" ]]; then
  export TERM=xterm-256color
fi

