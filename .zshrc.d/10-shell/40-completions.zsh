# Completion system and command-specific completions.

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

load_completion_if_cmd jj eval 'source <(COMPLETE=zsh jj)'
load_completion_if_cmd moodle eval 'source <(moodle completion zsh)'
load_completion_if_cmd codex eval 'eval "$(codex completion zsh)"'
load_completion_if_cmd uv eval 'eval "$(uv generate-shell-completion zsh)"'
load_completion_if_cmd uvx eval 'eval "$(uvx --generate-shell-completion zsh)"'
if has worktree; then
  typeset _worktree_completion
  _worktree_completion="$(worktree completion zsh 2>/dev/null)"
  if [[ -n "$_worktree_completion" ]]; then
    source /dev/stdin <<< "$_worktree_completion"
  fi
  unset _worktree_completion
fi

if [[ -s "$HOME/.bun/_bun" ]]; then
  source "$HOME/.bun/_bun"
fi

if [[ -f "$HOME/.local/google-cloud-sdk/completion.zsh.inc" ]]; then
  source "$HOME/.local/google-cloud-sdk/completion.zsh.inc"
fi
