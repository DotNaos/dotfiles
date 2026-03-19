# On-demand secret and environment helpers.
#
# Shared secret references live in ~/.zshrc.d/10-shell/60-shared-secrets.zsh.
# That module should only export literal op:// references. These helpers
# resolve them on demand, never during shell startup.

typeset -g DOTFILES_PROJECT_ENV_TEMPLATE="${DOTFILES_PROJECT_ENV_TEMPLATE:-.env.1password}"
typeset -g DOTFILES_PROJECT_ENV_DESTINATION="${DOTFILES_PROJECT_ENV_DESTINATION:-.env.local}"

op-ready() {
  local quiet=0

  if [[ "${1:-}" == "--quiet" ]]; then
    quiet=1
  fi

  if ! has op; then
    (( quiet == 1 )) || echo "1Password CLI ('op') is not installed."
    return 1
  fi

  if ! command op whoami >/dev/null 2>&1; then
    (( quiet == 1 )) || echo "1Password CLI is not signed in."
    return 1
  fi

  return 0
}

op-read-ref() {
  local reference="${1:-}"

  if [[ -z "$reference" ]]; then
    echo "Usage: op-read-ref <op://reference>"
    return 2
  fi

  op-ready || return 1
  command op read "$reference"
}

_dotfiles_detect_shared_secret_vars() {
  emulate -L zsh

  local line key value
  local -a vars=()

  while IFS= read -r line; do
    key="${line%%=*}"
    value="${line#*=}"

    [[ -n "$key" && "$value" == op://* ]] || continue
    vars+=("$key")
  done < <(env)

  print -r -- "${vars[@]}"
}

secrets-shared-load() {
  emulate -L zsh

  local vars=("$@")
  local key value
  local loaded=0

  if (( ${#vars[@]} == 0 )); then
    vars=($(_dotfiles_detect_shared_secret_vars))
  fi

  if (( ${#vars[@]} == 0 )); then
    echo "No shared op:// variables defined. Add exports to ~/.zshrc.d/10-shell/60-shared-secrets.zsh"
    return 1
  fi

  op-ready || return 1

  for key in "${vars[@]}"; do
    value="${(P)key}"

    if [[ -z "$value" ]]; then
      echo "Shared secret variable is not set: $key"
      return 1
    fi

    if [[ "$value" != op://* ]]; then
      echo "Shared secret variable does not contain an op:// reference: $key"
      return 1
    fi

    value="$(command op read "$value" 2>/dev/null)" || {
      echo "Failed to read '$key' from 1Password."
      return 1
    }

    export "$key=$value"
    (( loaded++ ))
  done

  echo "Loaded $loaded shared secret variable(s)."
}

secrets-shared-run() {
  emulate -L zsh

  if [[ "${1:-}" == "--" ]]; then
    shift
  fi

  if (( $# == 0 )); then
    echo "Usage: secrets-shared-run -- <command> [args...]"
    return 2
  fi

  op-ready || return 1
  command op run -- "$@"
}

env-load() {
  emulate -L zsh
  setopt local_options allexport

  local files=("$@")
  local file
  local loaded=0

  if (( ${#files[@]} == 0 )); then
    files=(.env .env.local)
  fi

  for file in "${files[@]}"; do
    [[ -r "$file" ]] || continue

    source "$file" || {
      echo "Failed to source $file"
      return 1
    }

    (( loaded++ ))
  done

  if (( loaded == 0 )); then
    echo "No env files found."
    return 1
  fi

  echo "Loaded $loaded env file(s)."
}

env-run() {
  emulate -L zsh

  local files=()
  local args=()
  local file

  while (( $# > 0 )); do
    if [[ "$1" == "--" ]]; then
      shift
      break
    fi

    files+=("$1")
    shift
  done

  if (( $# == 0 )); then
    echo "Usage: env-run [env-file ...] -- <command> [args...]"
    return 2
  fi

  if (( ${#files[@]} == 0 )); then
    files=("$DOTFILES_PROJECT_ENV_TEMPLATE")
  fi

  for file in "${files[@]}"; do
    if [[ ! -r "$file" ]]; then
      echo "Env file not found: $file"
      return 1
    fi

    args+=("--env-file=$file")
  done

  op-ready || return 1
  command op run "${args[@]}" -- "$@"
}

env-inject() {
  emulate -L zsh

  local template="${1:-$DOTFILES_PROJECT_ENV_TEMPLATE}"
  local destination="${2:-$DOTFILES_PROJECT_ENV_DESTINATION}"

  if [[ ! -r "$template" ]]; then
    echo "Template file not found: $template"
    return 1
  fi

  op-ready || return 1

  command op inject -i "$template" -o "$destination" || return $?
  echo "Wrote injected env file to $destination."
}
