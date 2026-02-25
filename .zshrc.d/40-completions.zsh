# Completion system and command-specific completions.

fpath=("$HOME/.docker/completions" "$HOME/.zsh/completions" $fpath)

zstyle ':completion:*' sort false
zstyle ':completion:*' file-sort numerical
zstyle ':completion:*' list-suffixes true

if [[ -z "${__DOTFILES_COMPINIT_DONE:-}" ]]; then
  autoload -Uz compinit
  compinit
  typeset -g __DOTFILES_COMPINIT_DONE=1
fi

load_completion_if_cmd jj eval 'source <(COMPLETE=zsh jj)'
load_completion_if_cmd moodle eval 'source <(moodle completion zsh)'
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
