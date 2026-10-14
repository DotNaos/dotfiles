# Resolving in a child keeps the parent's NVM function undefined, so the OMZ
# plugin still installs its own lazy loader, completion and optional hooks.
dotfiles_resolve_nvm_path() {
  local selected
  selected="$(
    source "$NVM_DIR/nvm.sh" >/dev/null
    [[ "$(whence -p node 2>/dev/null)" == "${NVM_BIN:-}/node" ]] || exit 0
    print -r -- "$NVM_BIN"
  )" || return 0
  dotfiles_apply_nvm_path "$selected"
}

dotfiles_apply_nvm_path() {
  local selected="$1"
  [[ "$selected" == "$NVM_DIR"/versions/node/*/bin && -x "$selected/node" ]] || return 0
  path=("$selected" "${(@)path:#$NVM_DIR/versions/node/*/bin}")
  export PATH NVM_BIN="$selected" NVM_INC="${selected:h}/include/node"
  if [[ -n ${MANPATH:-} && ":$MANPATH:" != *":${selected:h}/share/man:"* ]]; then
    export MANPATH="${selected:h}/share/man:$MANPATH"
  fi
}

# Preserve all default-version Node commands while deferring NVM's shell setup.
# Resolve through NVM itself on a cache miss; do not reimplement version aliases.
dotfiles_prepare_nvm_path() {
  if [[ -z ${NVM_DIR:-} ]]; then
    if [[ -d "$HOME/.nvm" ]]; then
      export NVM_DIR="$HOME/.nvm"
    elif [[ -d "${XDG_CONFIG_HOME:-$HOME/.config}/nvm" ]]; then
      export NVM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvm"
    elif [[ -d "${NVM_HOMEBREW:-${HOMEBREW_PREFIX:-}/opt/nvm}" ]]; then
      export NVM_DIR="${NVM_HOMEBREW:-${HOMEBREW_PREFIX:-}/opt/nvm}"
    fi
  fi
  [[ -n ${NVM_DIR:-} && -r "$NVM_DIR/nvm.sh" ]] || return 0
  # Without a default alias, NVM can select a version from the current directory.
  # Keep that behavior uncached rather than caching a directory-specific choice.
  if [[ ! -r "$NVM_DIR/alias/default" ]]; then
    dotfiles_resolve_nvm_path
    return 0
  fi

  zmodload -F zsh/stat b:zstat || { dotfiles_resolve_nvm_path; return 0; }
  local nvm_current_node="$(whence -p node 2>/dev/null)"
  local nvm_file nvm_key="nvm-path-v1 ${(q)NVM_DIR} ${(q)nvm_current_node}"
  local -A nvm_stat
  for nvm_file in "$NVM_DIR/nvm.sh" "$NVM_DIR"/alias/**/*(N-.); do
    zstat -H nvm_stat "$nvm_file" 2>/dev/null || { dotfiles_resolve_nvm_path; return 0; }
    nvm_key+=" ${(q)nvm_file}:$nvm_stat[device]:$nvm_stat[inode]:$nvm_stat[mtime]:$nvm_stat[ctime]:$nvm_stat[size]"
    [[ "$nvm_file" == "$NVM_DIR"/alias/* ]] && nvm_key+=" ${(q)$(< "$nvm_file")}"
  done
  # Dynamic aliases such as `node` change when an installed version is added.
  local nvm_versions=("$NVM_DIR"/versions/node/*(N/:t))
  nvm_key+=" ${(j: :)nvm_versions}"
  local nvm_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
  local nvm_cache="$nvm_cache_dir/nvm-default-path"
  local nvm_header nvm_selected
  if [[ -f "$nvm_cache" && ! -L "$nvm_cache" ]]; then
    { IFS= read -r nvm_header; IFS= read -r nvm_selected; } < "$nvm_cache"
    if [[ "$nvm_header" == "$nvm_key" && "$nvm_selected" == "$NVM_DIR"/versions/node/*/bin && -x "$nvm_selected/node" ]]; then
      dotfiles_apply_nvm_path "$nvm_selected"
      return 0
    fi
  fi

  # First use or a changed alias/version: let the existing NVM choose normally.
  dotfiles_resolve_nvm_path
  nvm_selected="${NVM_BIN:-}"
  [[ "$(whence -p node 2>/dev/null)" == "$nvm_selected/node" ]] || return 0
  [[ "$nvm_selected" == "$NVM_DIR"/versions/node/*/bin && -x "$nvm_selected/node" ]] || return 0
  [[ ! -L "$nvm_cache_dir" && ! -L "$nvm_cache" ]] || return 0
  mkdir -p -m 700 "$nvm_cache_dir" 2>/dev/null || return 0
  local nvm_temporary="$nvm_cache.$$.${RANDOM}"
  if (umask 077; setopt noclobber; print -rl -- "$nvm_key" "$nvm_selected" > "$nvm_temporary") 2>/dev/null; then
    command mv -f "$nvm_temporary" "$nvm_cache" 2>/dev/null || command rm -f "$nvm_temporary" 2>/dev/null
  fi
  return 0
}
