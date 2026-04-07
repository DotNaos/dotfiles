# Shared environment bootstrap for every zsh process.

safe_source() {
  local file="$1"
  [[ -r "$file" ]] || return 0
  source "$file"
}

safe_source "${ZDOTDIR:-$HOME}/.zshrc.d/00-core/00-core.zsh"
safe_source "${ZDOTDIR:-$HOME}/.zshrc.d/10-shell/00-paths.zsh"

unfunction safe_source
