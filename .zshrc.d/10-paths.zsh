# PATH and environment variable setup.

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
