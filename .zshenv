# Shared environment bootstrap for every zsh process.

typeset -g DOTFILES_ROOT="${DOTFILES_ROOT:-${${(%):-%N}:A:h}}"

safe_source() {
  local file="$1"
  [[ -r "$file" ]] || return 0
  source "$file"
}

safe_source "${DOTFILES_ROOT}/scripts/lib/context.sh"
safe_source "${ZDOTDIR:-$HOME}/.zshrc.d/00-core/00-core.zsh"
safe_source "${ZDOTDIR:-$HOME}/.zshrc.d/10-shell/00-paths.zsh"

# Codex shells use the local read-only service account by default. Normal
# terminals never load it. Set either override to 1 for an interactive
# 1Password operation that must use the desktop app instead.
unset OP_SERVICE_ACCOUNT_TOKEN
if [[ "${CODEX_SHELL:-0}" == "1" \
  && "${CODEX_DONT_USE_1PASSWORD_SERVICE_ACCOUNT:-0}" != "1" \
  && "${OP_SERVICE_ACCOUNT_DISABLED:-0}" != "1" ]]; then
  safe_source "$HOME/.config/1password/op/service-account.env"
fi

unfunction safe_source
