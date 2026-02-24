# Ensure local wt-new CLI is installed and up to date.

DOTFILES_WT_NEW_ROOT="${DOTFILES_WT_NEW_ROOT:-$HOME/dotfiles/tools/wt-new}"
DOTFILES_WT_NEW_BIN="${DOTFILES_WT_NEW_BIN:-$HOME/.local/bin/wt-new}"

wt_new_needs_build() {
  [[ -x "$DOTFILES_WT_NEW_BIN" ]] || return 0

  find "$DOTFILES_WT_NEW_ROOT" -type f \
    \( -name '*.go' -o -name 'go.mod' -o -name 'go.sum' \) \
    -newer "$DOTFILES_WT_NEW_BIN" \
    -print -quit 2>/dev/null | grep -q .
}

ensure_wt_new_installed() {
  [[ -d "$DOTFILES_WT_NEW_ROOT" ]] || return 0
  has go || return 0

  if ! wt_new_needs_build; then
    return 0
  fi

  mkdir -p "${DOTFILES_WT_NEW_BIN:h}" || return 0
  (cd "$DOTFILES_WT_NEW_ROOT" && go build -o "$DOTFILES_WT_NEW_BIN" ./cmd/wt-new) >/dev/null 2>&1 || return 0
}

ensure_wt_new_installed
