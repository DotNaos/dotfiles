# Ensure local dotfiles CLI is installed and show update notices.

DOTFILES_ROOT="${DOTFILES_ROOT:-$HOME/dotfiles}"
DOTFILES_CLI_ROOT="${DOTFILES_CLI_ROOT:-$DOTFILES_ROOT/tools/dotfiles}"
DOTFILES_CLI_BIN="${DOTFILES_CLI_BIN:-$HOME/.local/bin/dotfiles}"
DOTFILES_UPDATE_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
DOTFILES_UPDATE_STAMP_FILE="${DOTFILES_UPDATE_CACHE_DIR}/last-fetch-date"

dotfiles_cli_needs_build() {
  [[ -x "$DOTFILES_CLI_BIN" ]] || return 0

  [[ -n "$(
    find "$DOTFILES_CLI_ROOT" -type f \
    \( -name '*.go' -o -name 'go.mod' -o -name 'go.sum' \) \
    -newer "$DOTFILES_CLI_BIN" \
    -print -quit 2>/dev/null
  )" ]]
}

ensure_dotfiles_cli_installed() {
  [[ -d "$DOTFILES_CLI_ROOT" ]] || return 0
  has go || return 0

  if ! dotfiles_cli_needs_build; then
    return 0
  fi

  mkdir -p "${DOTFILES_CLI_BIN:h}" || return 0
  (cd "$DOTFILES_CLI_ROOT" && go build -o "$DOTFILES_CLI_BIN" ./cmd/dotfiles) >/dev/null 2>&1 || return 0
}

dotfiles_daily_update_notice() {
  [[ -d "$DOTFILES_ROOT/.git" ]] || return 0
  has git || return 0

  local today current_branch upstream ahead behind
  today="$(date +%F)"

  mkdir -p "$DOTFILES_UPDATE_CACHE_DIR" 2>/dev/null || return 0

  if [[ -f "$DOTFILES_UPDATE_STAMP_FILE" ]] && [[ "$( < "$DOTFILES_UPDATE_STAMP_FILE")" == "$today" ]]; then
    return 0
  fi

  print -r -- "$today" >| "$DOTFILES_UPDATE_STAMP_FILE" 2>/dev/null || return 0
  git -C "$DOTFILES_ROOT" fetch --quiet --prune >/dev/null 2>&1 || return 0

  current_branch="$(git -C "$DOTFILES_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)" || return 0
  upstream="$(git -C "$DOTFILES_ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)" || return 0

  local counts
  counts="$(git -C "$DOTFILES_ROOT" rev-list --left-right --count HEAD..."$upstream" 2>/dev/null)" || return 0
  ahead="${counts%% *}"
  behind="${counts##* }"

  [[ "$ahead" =~ '^[0-9]+$' ]] || ahead=0
  [[ "$behind" =~ '^[0-9]+$' ]] || behind=0

  if (( behind > 0 )); then
    echo "dotfiles update available: $behind commit(s) behind $upstream"
    echo "run: dotfiles update"
  fi
}

ensure_dotfiles_cli_installed
dotfiles_daily_update_notice
