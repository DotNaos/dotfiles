#!/usr/bin/env sh

dotfiles_context_home() {
  printf '%s\n' "${DOTFILES_CONTEXT_HOME:-$HOME}"
}

dotfiles_context_config_path() {
  if [ -n "${DOTFILES_CONTEXT_CONFIG:-}" ]; then
    printf '%s\n' "$DOTFILES_CONTEXT_CONFIG"
    return 0
  fi

  printf '%s/.config/dotfiles/context.env\n' "$(dotfiles_context_home)"
}

dotfiles_detect_platform() {
  if [ "${OSTYPE:-}" != "${OSTYPE#darwin}" ]; then
    printf '%s\n' "macos"
    return 0
  fi

  if [ -n "${WSL_DISTRO_NAME:-}" ]; then
    printf '%s\n' "wsl"
    return 0
  fi

  if [ -r /proc/version ] && grep -qi microsoft /proc/version 2>/dev/null; then
    printf '%s\n' "wsl"
    return 0
  fi

  printf '%s\n' "linux"
}

dotfiles_detect_mode() {
  case "$-" in
    *i*) printf '%s\n' "interactive" ;;
    *) printf '%s\n' "noninteractive" ;;
  esac
}

dotfiles_detect_shell() {
  if [ -n "${DOTFILES_SHELL_HINT:-}" ]; then
    printf '%s\n' "$DOTFILES_SHELL_HINT"
    return 0
  fi

  if [ -n "${ZSH_VERSION:-}" ]; then
    printf '%s\n' "zsh"
    return 0
  fi

  if [ -n "${BASH_VERSION:-}" ]; then
    printf '%s\n' "bash"
    return 0
  fi

  if [ -n "${FISH_VERSION:-}" ]; then
    printf '%s\n' "fish"
    return 0
  fi

  if [ -n "${SHELL:-}" ]; then
    basename "$SHELL"
    return 0
  fi

  if [ -n "${0:-}" ]; then
    basename "$0"
    return 0
  fi

  printf '%s\n' "zsh"
}

dotfiles_load_context() {
  local context_file
  local explicit_platform explicit_role explicit_mode explicit_shell
  local explicit_platform_set explicit_role_set explicit_mode_set explicit_shell_set

  context_file="$(dotfiles_context_config_path)"

  explicit_platform="${DOTFILES_PLATFORM:-}"
  explicit_role="${DOTFILES_ROLE:-}"
  explicit_mode="${DOTFILES_MODE:-}"
  explicit_shell="${DOTFILES_SHELL:-}"

  explicit_platform_set=0
  explicit_role_set=0
  explicit_mode_set=0
  explicit_shell_set=0

  [ -n "${DOTFILES_PLATFORM+x}" ] && explicit_platform_set=1
  [ -n "${DOTFILES_ROLE+x}" ] && explicit_role_set=1
  [ -n "${DOTFILES_MODE+x}" ] && explicit_mode_set=1
  [ -n "${DOTFILES_SHELL+x}" ] && explicit_shell_set=1

  if [ -r "$context_file" ]; then
    # shellcheck disable=SC1090
    . "$context_file"
  fi

  [ "$explicit_platform_set" -eq 1 ] && DOTFILES_PLATFORM="$explicit_platform"
  [ "$explicit_role_set" -eq 1 ] && DOTFILES_ROLE="$explicit_role"
  [ "$explicit_mode_set" -eq 1 ] && DOTFILES_MODE="$explicit_mode"
  [ "$explicit_shell_set" -eq 1 ] && DOTFILES_SHELL="$explicit_shell"

  DOTFILES_PLATFORM="${DOTFILES_PLATFORM:-$(dotfiles_detect_platform)}"
  DOTFILES_ROLE="${DOTFILES_ROLE:-default}"
  DOTFILES_MODE="${DOTFILES_MODE:-$(dotfiles_detect_mode)}"
  DOTFILES_SHELL="${DOTFILES_SHELL:-$(dotfiles_detect_shell)}"

  export DOTFILES_CONTEXT_CONFIG="$context_file"
  export DOTFILES_PLATFORM
  export DOTFILES_ROLE
  export DOTFILES_MODE
  export DOTFILES_SHELL
}
