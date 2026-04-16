# Reuse the universal zsh bootstrap when `.zshrc` is sourced manually in an
# already-running shell.
if [[ -f "$HOME/.zshenv" ]]; then
  source "$HOME/.zshenv"
fi

# Non-interactive shells should not load prompt tooling or other interactive
# shell setup. This prevents `source ~/.zshrc` from emitting starship errors
# in CLI-only commands.
if [[ ! -o interactive ]]; then
  return 0
fi

# Ensure Zinit exists
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d "${ZINIT_HOME}" ]]; then
  echo "Zinit not found, installing..."
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Load Zinit
source "${ZINIT_HOME}/zinit.zsh"

DOTFILES_ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
mkdir -p "$DOTFILES_ZSH_CACHE_DIR"
ZINIT[ZCOMPDUMP_PATH]="${DOTFILES_ZSH_CACHE_DIR}/.zcompdump-${HOST%%.*}-${ZSH_VERSION}"

# Keep this file minimal (bootstrap/loader only).
# Put all regular configuration in modules under ~/.zshrc.d/.
#
# Modules load recursively in lexical path order, so top-level numbered
# folders define the coarse order and numbered files inside each folder
# define the local order.
ZSHRC_D="${ZDOTDIR:-$HOME}/.zshrc.d"
if [[ -d "$ZSHRC_D" ]]; then
  for __dotfiles_module in "$ZSHRC_D"/**/*.zsh(N); do
    source "$__dotfiles_module"
  done
  unset __dotfiles_module
fi
