# Start Colima on demand so `docker` works without Docker Desktop.

case "${DOTFILES_PLATFORM:-${OSTYPE:-}}" in
  macos|darwin*) ;;
  *) return 0 ;;
esac

__docker_client_only_subcommand() {
  case "${1:-}" in
    ""|-h|--help|help|completion|context)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

__ensure_colima_docker() {
  has colima || return 0

  __docker_client_only_subcommand "$1" && return 0

  if command docker info >/dev/null 2>&1; then
    return 0
  fi

  if [[ "$(command docker context show 2>/dev/null)" != "colima" ]]; then
    command docker context use colima >/dev/null 2>&1 || true
  fi

  if ! colima status 2>/dev/null | grep -q "colima is running"; then
    print -u2 "Starting Colima so Docker can run..."
    colima start >/dev/null 2>&1 || {
      print -u2 "Colima could not be started automatically."
      return 1
    }
  fi

  command docker info >/dev/null 2>&1 || {
    print -u2 "Docker is still unavailable after starting Colima."
    return 1
  }
}

docker() {
  __ensure_colima_docker "$@" || return $?
  command docker "$@"
}
