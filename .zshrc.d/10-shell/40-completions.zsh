# Completion system and command-specific completions.

dotfiles_load_generated_completion() {
  local cmd="$1"
  shift

  local completion

  has "$cmd" || return 0

  completion="$("$@" 2>/dev/null)" || return 0
  [[ -n "$completion" ]] || return 0

  source /dev/stdin <<< "$completion"
}

dotfiles_init_completions() {
  [[ -n "${__DOTFILES_COMPLETIONS_DONE:-}" ]] && return 0

  fpath=("$HOME/.docker/completions" "$HOME/.zsh/completions" $fpath)

  zstyle ':completion:*' sort false
  zstyle ':completion:*' file-sort numerical
  zstyle ':completion:*' list-suffixes true

  typeset -g DOTFILES_ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
  typeset -g DOTFILES_ZCOMPDUMP_FILE="${DOTFILES_ZCOMPDUMP_FILE:-$DOTFILES_ZSH_CACHE_DIR/.zcompdump-${HOST%%.*}-${ZSH_VERSION}}"

  mkdir -p "$DOTFILES_ZSH_CACHE_DIR"

  if [[ -z "${__DOTFILES_COMPINIT_DONE:-}" ]]; then
    autoload -Uz compinit
    compinit -d "$DOTFILES_ZCOMPDUMP_FILE"
    typeset -g __DOTFILES_COMPINIT_DONE=1
  fi

  for _toolkit_completion in \
    "$HOME/.zsh/completions/_agent-chat" \
    "$HOME/.zsh/completions/_agent-memory" \
    "$HOME/.zsh/completions/_ui-loop" \
    "$HOME/.zsh/completions/_agent-hub" \
    "$HOME/.zsh/completions/_agent-delegate"; do
    if [[ -f "$_toolkit_completion" ]]; then
      source "$_toolkit_completion"
    fi
  done
  unset _toolkit_completion

  dotfiles_load_generated_completion jj env COMPLETE=zsh jj
  dotfiles_load_generated_completion moodle moodle completion zsh
  dotfiles_load_generated_completion codex codex completion zsh
  dotfiles_load_generated_completion dotfiles dotfiles completion zsh
  dotfiles_load_generated_completion project project completion zsh
  dotfiles_load_generated_completion uv uv generate-shell-completion zsh
  dotfiles_load_generated_completion uvx uvx --generate-shell-completion zsh
  dotfiles_load_generated_completion worktree worktree completion zsh

  if [[ -s "$HOME/.bun/_bun" ]]; then
    source "$HOME/.bun/_bun"
  fi

  if [[ -f "$HOME/.local/google-cloud-sdk/completion.zsh.inc" ]]; then
    source "$HOME/.local/google-cloud-sdk/completion.zsh.inc"
  fi

  typeset -g __DOTFILES_COMPLETIONS_DONE=1
}
