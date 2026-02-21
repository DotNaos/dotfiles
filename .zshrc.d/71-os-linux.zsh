# Native Linux-specific setup (non-WSL).

[[ "$DOTFILES_PLATFORM" == "linux" ]] || return 0

if [[ -z "${GNOME_KEYRING_CONTROL:-}" ]] && has gnome-keyring-daemon; then
  eval "$(gnome-keyring-daemon --start --components=secrets 2>/dev/null)"
  export GNOME_KEYRING_CONTROL
fi
