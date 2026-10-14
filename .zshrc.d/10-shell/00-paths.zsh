# PATH and environment variable setup.

if [[ -z "${PATH:-}" ]]; then
  export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
fi

# Homebrew's stable environment without starting brew on every shell launch.
# Keep the prefix selection used by this configuration on macOS and Linux.
for __brew_prefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew "$HOME/.linuxbrew"; do
  [[ -x "$__brew_prefix/bin/brew" ]] || continue
  export HOMEBREW_PREFIX="$__brew_prefix"
  export HOMEBREW_CELLAR="$__brew_prefix/Cellar"
  if [[ "$__brew_prefix" == /usr/local ]]; then
    export HOMEBREW_REPOSITORY="$__brew_prefix/Homebrew"
  else
    export HOMEBREW_REPOSITORY="$__brew_prefix"
  fi
  typeset -gU path fpath
  path=("$__brew_prefix/bin" "$__brew_prefix/sbin" $path)
  fpath=("$__brew_prefix/share/zsh/site-functions" $fpath)
  export PATH FPATH
  if [[ -n ${MANPATH:-} ]]; then
    export MANPATH=":${${MANPATH##:}%%:}"
  fi
  if [[ ":${INFOPATH:-}:" != *":$__brew_prefix/share/info:"* ]]; then
    export INFOPATH="$__brew_prefix/share/info:${INFOPATH:-}"
  fi
  break
done
unset __brew_prefix

append_path_once "/usr/bin"
append_path_once "/bin"
append_path_once "/usr/sbin"
append_path_once "/sbin"

export DOTNET_ROOT="$HOME/.dotnet"
export BUN_INSTALL="$HOME/.bun"

append_path_once "$HOME/.local/bin"
append_path_once "$HOME/.dotnet"
append_path_once "$HOME/.dotnet/tools"
append_path_once "$HOME/.modular/bin"
append_path_once "$HOME/.lmstudio/bin"
append_path_once "$HOME/.codeium/windsurf/bin"
append_path_once "$HOME/.antigravity/antigravity/bin"
append_path_once "$HOME/.bun/bin"
append_path_once "$HOME/go/bin"
append_path_once "$HOME/.local/google-cloud-sdk/bin"

case "$DOTFILES_PLATFORM" in
  macos)
    export PNPM_HOME="$HOME/Library/pnpm"
    append_path_once "$PNPM_HOME"
    append_path_once "/opt/homebrew/opt/libpq/bin"
    ;;
  linux|wsl)
    export PNPM_HOME="$HOME/.local/share/pnpm"
    append_path_once "$PNPM_HOME"
    ;;
esac

for __nvm_node_bin in /home/linuxbrew/.linuxbrew/opt/nvm/versions/node/*/bin(N); do
  append_path_once "$__nvm_node_bin"
done
unset __nvm_node_bin

FNM_PATH="$HOME/.local/share/fnm"
if [[ -d "$FNM_PATH" ]]; then
  append_path_once "$FNM_PATH"
  if [[ -z ${__DOTFILES_FNM_READY:-} ]] && has fnm; then
    typeset -g __DOTFILES_FNM_READY=1
    eval "$(fnm env)"
  fi
fi
