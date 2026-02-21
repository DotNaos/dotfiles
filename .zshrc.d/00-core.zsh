# Shared helper functions used by subsequent modules.

detect_platform() {
  if [[ "$OSTYPE" == darwin* ]]; then
    echo "macos"
    return 0
  fi

  if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    echo "wsl"
    return 0
  fi

  if [[ -r /proc/version ]] && grep -qi 'microsoft' /proc/version 2>/dev/null; then
    echo "wsl"
    return 0
  fi

  echo "linux"
}

typeset -g DOTFILES_PLATFORM="${DOTFILES_PLATFORM:-$(detect_platform)}"

has() {
  command -v "$1" >/dev/null 2>&1
}

append_path_once() {
  local dir="$1"
  [[ -z "$dir" ]] && return 0

  case ":$PATH:" in
    *":$dir:"*) ;;
    *) export PATH="$dir:$PATH" ;;
  esac
}

safe_source() {
  local file="$1"
  [[ -r "$file" ]] || return 0
  source "$file"
}

load_completion_if_cmd() {
  local cmd="$1"
  local mode="$2"
  local payload="$3"

  has "$cmd" || return 0

  case "$mode" in
    eval)
      eval "$payload"
      ;;
    source)
      [[ -r "$payload" ]] && source "$payload"
      ;;
    *)
      return 1
      ;;
  esac
}
