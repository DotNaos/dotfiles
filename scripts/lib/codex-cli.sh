#!/usr/bin/env bash

dotfiles_codex_cli() {
  local binary="${DOTFILES_CLI:-$ROOT_DIR/tools/dotfiles/dotfiles}"
  if [[ -z "${DOTFILES_CLI:-}" && ! -x "$binary" ]]; then
    binary="$(command -v dotfiles || true)"
  fi
  if [[ -z "$binary" || ! -x "$binary" ]] ||
    ! "$binary" render-codex --fingerprint-live --help >/dev/null 2>&1; then
    printf 'Build an up-to-date dotfiles CLI first (see README); no configuration was changed.\n' >&2
    return 1
  fi
  printf '%s\n' "$binary"
}
