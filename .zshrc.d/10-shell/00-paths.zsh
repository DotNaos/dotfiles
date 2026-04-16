# PATH and environment variable setup.

if [[ -z "${PATH:-}" ]]; then
  export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
fi

if [[ -f "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f "/usr/local/bin/brew" ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
elif [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [[ -f "$HOME/.linuxbrew/bin/brew" ]]; then
  eval "$($HOME/.linuxbrew/bin/brew shellenv)"
fi

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
  eval "$(fnm env)"
fi
