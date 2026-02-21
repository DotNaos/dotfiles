# Local, machine- or user-specific overrides.

if [[ "${CLAUDECODE:-0}" != "1" ]]; then
  safe_source "${ZDOTDIR:-$HOME}/.zshrc_user"
fi

safe_source "${ZDOTDIR:-$HOME}/.zshrc.local"

if has zinit; then
  zinit cdreplay -q
fi
