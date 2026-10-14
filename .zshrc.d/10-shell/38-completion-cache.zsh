# Generated shell code is cached per executable, arguments and zsh version.
# No cache is shared with other users or checked into the repository.
dotfiles_load_generated_completion() {
  local cmd="$1"
  shift
  has "$cmd" || return 0

  builtin hash "$cmd" 2>/dev/null || return 0
  local executable="${commands[$cmd]:A}"
  [[ -x "$executable" ]] || return 0
  zmodload -F zsh/stat b:zstat || return 0
  local -A executable_stat
  zstat -H executable_stat "$executable" 2>/dev/null || return 0

  local cache_dir="${DOTFILES_ZSH_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/zsh}/generated"
  local cache_file="$cache_dir/$cmd.zsh"
  local signature="# dotfiles-cache-v2 $ZSH_VERSION ${(q)executable} $executable_stat[device] $executable_stat[inode] $executable_stat[mtime] $executable_stat[ctime] $executable_stat[size] ${(j: :)${(q)@}}"
  local header
  if [[ -f "$cache_file" && ! -L "$cache_file" ]]; then
    IFS= read -r header < "$cache_file"
    if [[ "$header" == "$signature" ]]; then
      source "$cache_file"
      return 0
    fi
  fi

  # Only publish a complete successful generation, never a partial write.
  [[ ! -L "$cache_dir" && ! -L "$cache_file" ]] || return 0
  mkdir -p -m 700 "$cache_dir" 2>/dev/null || return 0
  local temporary="$cache_file.$$.${RANDOM}"
  local generated
  if generated="$("$@" 2>/dev/null)" && [[ -n "$generated" ]] \
      && (umask 077; setopt noclobber; print -rl -- "$signature" "$generated" > "$temporary") 2>/dev/null \
      && command mv -f "$temporary" "$cache_file" 2>/dev/null; then
    source "$cache_file"
  else
    command rm -f "$temporary" 2>/dev/null
    # Preserve a usable previous completion if an updated generator fails.
    [[ -f "$cache_file" && ! -L "$cache_file" ]] && source "$cache_file"
  fi
  return 0
}
