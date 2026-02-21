# Custom shell functions.

safe_source "${ZDOTDIR:-$HOME}/.zshrc_functions"

pls() {
  local prompt="$*"
  if [[ -z "$prompt" ]]; then
    echo "Usage: pls <prompt>"
    return 1
  fi

  command codex --dangerously-bypass-approvals-and-sandbox "$prompt"
}

fuck() {
  has thefuck || {
    echo "thefuck is not installed"
    return 127
  }

  TF_PYTHONIOENCODING=$PYTHONIOENCODING
  export TF_SHELL=zsh
  export TF_ALIAS=fuck
  TF_SHELL_ALIASES=$(alias)
  export TF_SHELL_ALIASES
  TF_HISTORY="$(fc -ln -10)"
  export TF_HISTORY
  export PYTHONIOENCODING=utf-8

  TF_CMD=$(thefuck THEFUCK_ARGUMENT_PLACEHOLDER "$@") && eval "$TF_CMD"

  unset TF_HISTORY
  export PYTHONIOENCODING=$TF_PYTHONIOENCODING
  [[ -n "$TF_CMD" ]] && print -s "$TF_CMD"
}
