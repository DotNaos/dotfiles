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

# Auto-start tmux for interactive shells
if [[ -z "$TMUX" && -n "$PS1" && -t 1 ]]; then
  if command -v tmux >/dev/null 2>&1; then
    exec tmux new-session -A -s main
  fi
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

# Load user-only interactive customizations unless running in automated mode
if [[ "$CLAUDECODE" != "1" ]] && [[ -f "$HOME/.zshrc_user" ]]; then
  source "$HOME/.zshrc_user"
fi

# Load zsh functions and custom commands
source "$HOME/.zshrc_functions"

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
zinit snippet OMZP::jj
source <(COMPLETE=zsh jj)
# Load completions
# Enable numeric (alphanumerical) sorting in completion
zstyle ':completion:*' sort false
zstyle ':completion:*' file-sort numerical
zstyle ':completion:*' list-suffixes true

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
alias code="code-insiders"

pls() {
    local prompt="$*"
    if [[ -z "$prompt" ]]; then
        echo "Usage: pls <prompt>"
        return 1
    fi
    command codex --dangerously-bypass-approvals-and-sandbox "$prompt"
}
################ ENV VARS ################

export DOTENV_ALWAYS_LOAD=1


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
# Usage: add_to_path <path> [os]
# os can be: darwin (macOS), linux, or empty (all systems)
add_to_path() {
    local path="$1"
    local target_os="$2"

    # Use built-in OSTYPE variable instead of external commands
    local current_os=""
    case "$OSTYPE" in
        darwin*) current_os="darwin" ;;
        linux*) current_os="linux" ;;
        *) current_os="unknown" ;;
    esac

    # If target_os is specified and doesn't match current OS, skip
    if [[ -n "$target_os" && "$target_os" != "$current_os" ]]; then
        return
    fi

    case ":$PATH:" in
        *":$path:"*) ;;
        *) export PATH="$path:$PATH" ;;
    esac
}

# Add various tools to PATH
# OS specific paths
add_to_path "$HOME/.local/share/pnpm" "linux" # PNPM for Linux
add_to_path "$HOME/Library/pnpm" "darwin" # PNPM for macOS

add_to_path "/opt/homebrew/opt/libpq/bin" "darwin"

add_to_path "$HOME/.modular/bin"
add_to_path "$HOME/.lmstudio/bin"
add_to_path "$HOME/.codeium/windsurf/bin"
add_to_path "$HOME/.dotnet/tools"
add_to_path "$HOME/.dotnet/"

################ SHELL INTEGRATION ################
if [[ "$OSTYPE" == darwin* ]]; then
  eval "$(fzf --zsh)"
fi
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

eval "$(rbenv init - zsh)"

# In ~/.zshrc  (oder ~/.bashrc)
if [[ "$TERM" == "xterm-ghostty" ]]; then
  export TERM=xterm-256color
fi
export PATH="$HOME/.local/bin:$PATH"
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=(/Users/oli/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

# bun completions
[ -s "/Users/oli/.bun/_bun" ] && source "/Users/oli/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# 1Password sssh
export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

export DOTENV_CONFIG_AUTO=1

# Added by Antigravity
export PATH="/Users/oli/.antigravity/antigravity/bin:$PATH"

# pnpm
export PNPM_HOME="/Users/oli/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end


# TODO: Maybe move this into the wsl/linux config?
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$DOTNET_ROOT:$PATH"
export PATH="$PATH:$HOME/.dotnet/tools"
export PATH="$HOME/.local/bin:$PATH"

# Start gnome-keyring for secret storage
if [ -z "$GNOME_KEYRING_CONTROL" ]; then
    eval $(gnome-keyring-daemon --start --components=secrets 2>/dev/null)
    export GNOME_KEYRING_CONTROL
fi
alias uijj='lazyjj'


# Go bin path for moodle-cli
export PATH="$PATH:/Users/oli/go/bin"

# moodle-cli completions
autoload -Uz compinit && compinit
source <(moodle completion zsh)

# Go bin path for moodle-cli
export PATH="$PATH:/Users/oli/go/bin"

# moodle-cli completions
autoload -Uz compinit && compinit
source <(moodle completion zsh)


 # TODO: Maybe move this into the wsl/linux config?
 export DOTNET_ROOT="$HOME/.dotnet"
 export PATH="$DOTNET_ROOT:$PATH"
 export PATH="$PATH:$HOME/.dotnet/tools"
 export PATH="$HOME/.local/bin:$PATH"

 # Start gnome-keyring for secret storage
 if [ -z "$GNOME_KEYRING_CONTROL" ]; then
     eval $(gnome-keyring-daemon --start --components=secrets 2>/dev/null)
     export GNOME_KEYRING_CONTROL
 fi
 alias uijj='lazyjj'
