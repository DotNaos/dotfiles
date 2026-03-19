# Ensure local worktree CLI is installed and up to date.

DOTFILES_WORKTREE_ROOT="${DOTFILES_WORKTREE_ROOT:-$HOME/dotfiles/tools/worktree}"
DOTFILES_WORKTREE_BIN="${DOTFILES_WORKTREE_BIN:-$HOME/.local/bin/worktree}"

worktree_needs_build() {
  [[ -x "$DOTFILES_WORKTREE_BIN" ]] || return 0

  [[ -n "$(
    find "$DOTFILES_WORKTREE_ROOT" -type f \
    \( -name '*.go' -o -name 'go.mod' -o -name 'go.sum' \) \
    -newer "$DOTFILES_WORKTREE_BIN" \
    -print -quit 2>/dev/null
  )" ]]
}

ensure_worktree_installed() {
  [[ -d "$DOTFILES_WORKTREE_ROOT" ]] || return 0
  has go || return 0

  if ! worktree_needs_build; then
    return 0
  fi

  mkdir -p "${DOTFILES_WORKTREE_BIN:h}" || return 0
  (cd "$DOTFILES_WORKTREE_ROOT" && go build -o "$DOTFILES_WORKTREE_BIN" ./cmd/worktree) >/dev/null 2>&1 || return 0
}

ensure_worktree_installed

# Allow `worktree switch <branch>` to change the current shell directory.
# A standalone binary cannot `cd` the parent shell, so this wrapper evals
# the emitted `cd ...` command for switch operations.
worktree() {
  if [[ "$1" == "new" ]]; then
    shift

    local create_mode=0
    local has_branch_flag=0
    local passthrough=()
    local arg

    for arg in "$@"; do
      case "$arg" in
        -c|--create)
          create_mode=1
          ;;
        --branch)
          has_branch_flag=1
          passthrough+=("$arg")
          ;;
        --branch=*)
          has_branch_flag=1
          passthrough+=("$arg")
          ;;
        *)
          passthrough+=("$arg")
          ;;
      esac
    done

    if (( create_mode == 1 && has_branch_flag == 0 )); then
      local new_branch
      printf "New branch name: "
      read -r new_branch
      [[ -n "$new_branch" ]] || return 1
      passthrough+=("--branch" "$new_branch")
      has_branch_flag=1
    fi

    if (( create_mode == 0 && has_branch_flag == 0 && ${#passthrough[@]} == 0 )); then
      local selected_branch
      if has fzf; then
        selected_branch="$(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null | fzf --prompt='branch> ' --height=40% --reverse)" || return $?
      else
        echo "worktree new: missing branch (use --branch <name> or install fzf for interactive picker)" >&2
        return 1
      fi

      [[ -n "$selected_branch" ]] || return 1
      passthrough+=("--branch" "$selected_branch")
    fi

    if (( has_branch_flag == 0 )); then
      command worktree new "${passthrough[@]}"
      return $?
    fi

    local output
    output="$(command worktree new --cd "${passthrough[@]}")" || return $?
    [[ -n "$output" ]] && eval "$output"
    return $?
  fi

  if [[ "$1" == "switch" || "$1" == "cd" ]]; then
    local subcommand="$1"
    shift

    if (( $# == 0 )); then
      if has fzf; then
        local selected_branch
        selected_branch="$(command worktree list --plain | fzf --prompt='worktree> ' --height=40% --reverse)" || return $?
        [[ -n "$selected_branch" ]] || return 1
        eval "$(command worktree switch --cd "$selected_branch")"
        return $?
      fi

      echo "worktree switch: missing target (install fzf for interactive picker)" >&2
      return 1
    fi

    local has_help=0
    local has_cd=0
    local arg
    for arg in "$@"; do
      [[ "$arg" == "-h" || "$arg" == "--help" ]] && has_help=1
      [[ "$arg" == "--cd" ]] && has_cd=1
    done

    if (( has_help )); then
      command worktree "$subcommand" "$@"
      return $?
    fi

    local output
    if (( has_cd )); then
      output="$(command worktree "$subcommand" "$@")" || return $?
    else
      output="$(command worktree "$subcommand" --cd "$@")" || return $?
    fi

    [[ -n "$output" ]] && eval "$output"
    return $?
  fi

  if [[ "$1" == "remove" || "$1" == "rm" || "$1" == "delete" ]]; then
    local subcommand="$1"
    shift

    if (( $# == 0 )); then
      if has fzf; then
        local selected_branch
        selected_branch="$(command worktree list --plain | fzf --prompt='remove worktree> ' --height=40% --reverse)" || return $?
        [[ -n "$selected_branch" ]] || return 1
        command worktree "$subcommand" --branch "$selected_branch"
        return $?
      fi

      echo "worktree remove: missing target (use argument/--branch/--path, or install fzf)" >&2
      return 1
    fi

    command worktree "$subcommand" "$@"
    return $?
  fi

  command worktree "$@"
}
