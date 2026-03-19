# macOS-specific shell setup.

[[ "$DOTFILES_PLATFORM" == "macos" ]] || return 0

if [[ "$TERM" == "xterm-ghostty" ]]; then
  export TERM=xterm-256color
fi

if [[ "$TERM_PROGRAM" == "kiro" ]] && has kiro; then
  source "$(kiro --locate-shell-integration-path zsh)"
fi

if has fzf; then
  eval "$(fzf --zsh)"
fi

DOTFILES_1PASSWORD_SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
if [[ -S "$DOTFILES_1PASSWORD_SSH_AUTH_SOCK" ]]; then
  export SSH_AUTH_SOCK="$DOTFILES_1PASSWORD_SSH_AUTH_SOCK"
fi
