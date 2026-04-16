# WSL-specific setup.

[[ "$DOTFILES_PLATFORM" == "wsl" ]] || return 0

export DOTFILES_IN_WSL=1

if [[ "$TERM" == "xterm-ghostty" ]]; then
  export TERM=xterm-256color
fi

alias pbcopy='clip.exe'
alias pbpaste='powershell.exe -NoProfile -Command Get-Clipboard'
