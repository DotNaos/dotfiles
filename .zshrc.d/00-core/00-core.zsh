# Shared helper functions used by subsequent modules.

if type dotfiles_load_context >/dev/null 2>&1; then
  dotfiles_load_context
fi

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
