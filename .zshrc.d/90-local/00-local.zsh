# Local, machine- or user-specific overrides.

if [[ "${CLAUDECODE:-0}" != "1" ]]; then
  safe_source "${ZDOTDIR:-$HOME}/.zshrc_user"
fi

if [[ -r "$HOME/.env" ]]; then
  set -a
  source "$HOME/.env"
  set +a
fi

safe_source "${ZDOTDIR:-$HOME}/.zshrc.local"

if type dotfiles_init_completions >/dev/null 2>&1; then
  dotfiles_init_completions
fi

if has zinit && (( $+functions[compdef] )); then
  zinit cdreplay -q
fi
