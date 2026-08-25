# Devbox CLI integration.

DEVBOX_ZSH_COMPLETION="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions/_devbox"

if [[ -r "$DEVBOX_ZSH_COMPLETION" ]]; then
  if (( ! $+functions[compdef] )); then
    autoload -Uz compinit
    compinit
  fi
  source "$DEVBOX_ZSH_COMPLETION"
fi

unset DEVBOX_ZSH_COMPLETION
