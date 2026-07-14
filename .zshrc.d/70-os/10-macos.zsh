# macOS-specific shell setup.

[[ "$DOTFILES_PLATFORM" == "macos" ]] || return 0

if [[ -x "/Applications/Blender.app/Contents/MacOS/Blender" ]]; then
  append_path_once "/Applications/Blender.app/Contents/MacOS"
fi

if [[ "$TERM" == "xterm-ghostty" ]]; then
  export TERM=xterm-256color
fi

if [[ "$TERM_PROGRAM" == "kiro" ]] && has kiro; then
  source "$(kiro --locate-shell-integration-path zsh)"
fi

if has fzf; then
  eval "$(fzf --zsh)"
fi
