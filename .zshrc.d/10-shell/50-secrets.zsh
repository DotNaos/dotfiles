# On-demand environment helper. Shell startup never sources project env files.

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
