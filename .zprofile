# Login setup follows /etc/zprofile, whose path_helper can reorder PATH.
# The paths module uses shell builtins and is safe to apply again.
safe_source "${DOTFILES_ROOT}/.zshrc.d/10-shell/00-paths.zsh"
